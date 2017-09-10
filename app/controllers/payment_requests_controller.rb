class PaymentRequestsController < ApplicationController
  # before_filter :authenticate_user!, :except => [:index]
  # before_filter :payment_request_user?, :except => [:index, :new, :create]
  respond_to :html, :json
  # respond_to :js, only: :create
  
  include Crypto # module in /lib
  require 'btcruby/extensions'
  require 'rest-client'

  def index
    @payment_requests = PaymentRequest.where.not(:key_path => nil).page(params[:page]).order(created_at: :desc) 
    respond_with(@payment_requests)
  end
  
  
  def new
    @payment_request = PaymentRequest.new
    # @payment_request.expiry_date  ||= Time.now.utc  # will set the default value only if it's nil
    @payment_request.r = Random.new.bytes(32).unpack('H*')[0].to_i(16) # 256-bit random integer
    @payment_request.blinding_factor = Random.new.bytes(32).unpack('H*')[0].to_i(16) # 256-bit random integer
    real_indices = []
    prng = Random.new
    while real_indices.count < 42
      j = prng.rand(0..83)
      unless real_indices.include? j
        real_indices << j
      end
    end
    @payment_request.real_indices = real_indices.sort

    salt = Figaro.env.tumblebit_salt
    index = (salt.to_i + prng.rand(0..99999)) % 0x80000000
    @payment_request.key_path = "1/#{index}"
  end
  
  
  def create
    @payment_request = PaymentRequest.new(payment_request_params)
    puts "#{payment_request_params}"
    # create @payment_request on Tumbler side
    response= RestClient.post $TUMBLER_PAYMENT_REQUEST_API_URL, {payment_request: {bob_public_key: @payment_request.bob_public_key}}
    result = JSON.parse(response.body)

    # get Tumbler key in http response and save it to @payment_request in Bob wallet
    if valid_pubkey?(result["tumbler_public_key"])
      @payment_request.tumbler_public_key = result["tumbler_public_key"]
      @payment_request.expiry_date = result["expiry_date"]
      @payment_request.request_created # update state from "started" to "step1"
      if @payment_request.save
        flash[:notice] = "Payment Request was successfully created"
        render "show"
      else
        flash[:alert] = "There was a problem with this payment request creation."
        redirect_to payment_requests_url
      end
    else
      flash[:alert] = "Invalid Tumbler public key."
      redirect_to payment_requests_url
    end
    
  end
  
  
  def show
    @payment_request = PaymentRequest.find(params[:id])
    response= RestClient.get($TUMBLER_PAYMENT_REQUEST_API_URL + "/#{@payment_request.bob_public_key}")
    result = JSON.parse(response.body)
    if @payment_request.tumbler_public_key == result["tumbler_public_key"]
      respond_with(@payment_request)
    else
      flash[:alert] = "This payment request seems to be unknown from the Tumbler or the Tumbler API is down."
      redirect_to payment_requests_url
    end
  end
  

  def edit
    @payment_request = PaymentRequest.find(params[:id])
    respond_with(@payment_request)
  end
  

  def update
    @payment_request = PaymentRequest.find(params[:id])
    @payment_request.update_attributes(payment_request_params)
    @notice = ""
    
    unless valid_pubkey?(@payment_request.tumbler_public_key)
      @notice << "Invalid Tumbler Public Key. "
    end
        
    if @notice.blank?
      # TODO: when puzzle solution is saved, lauch the "complete" method
      if @payment_request.aasm_state == "step10"
        blinding_factor = @payment_request.blinding_factor.to_i
        epsilon = @payment_request.solution.to_i(16)/blinding_factor
        puts "Epsilon= #{epsilon.to_s(16)}"
        @payment_request.escrow_tx_broadcasted # transition payment request state from "step10" to "step12"
        @payment_request.puzzle_solution_received # transition payment request state from "step12" to "completed"
        @payment_request.save
        redirect_to @payment_request, notice: 'Puzzle solution was successfully checked by Bob.'
      else
        flash[:notice] = "Payment request was successfully updated."
        respond_with(@payment_request)
      end
    else
      redirect_to @payment_request, alert: @notice
    end
  end # of update method
  
  
  def destroy
    @payment_request = PaymentRequest.find_by_id(params[:id])
    if !@payment_request.funded?
      @payment_request.destroy
      redirect_to payment_requests_path, notice: 'Payment request was successfully deleted.'
    else
      redirect_to @payment_request, alert: 'Payment request was funded, it cannot be deleted.'
    end
  end
  
  
  def bob_step_2
    # Steps 2 through 10 in Tumbler-Bob interactions, performed by Bob
    # step2: Bob generates 42 “real” payout addresses (keeps them secret for now) and prepares 42 distinct “real” transactions.
    @payment_request = PaymentRequest.find(params[:id])
    @funded_address = @payment_request.hash_address

    response= RestClient.get($TUMBLER_PAYMENT_REQUEST_API_URL + "/#{@payment_request.bob_public_key}")
    result = JSON.parse(response.body)
    @payment_request.tx_hash = result["utxo"]["tx_hash"]
    @payment_request.index = result["utxo"]["index"]
    @payment_request.amount = result["utxo"]["amount"]
    @payment_request.confirmations = result["utxo"]["confirmations"]
    @payment_request.escrow_tx_received # transition in state machine from "step1" to "step2"
    @payment_request.save

    if @payment_request.beta_values.blank?

      beta = []
      @payment_request.real_indices.each do |i|
        beta[i] = @payment_request.real_btc_tx_sighash(i)
      end
    
      # In Step 3, Bob picks a random secret 256-bit blinding factor r and prepares 42 “fake” transactions.
      # Fake transaction i pays Tumbler compressed Bitcoin address 1 BTC in output 0 
      # with an OP_RETURN output (output 1) bearing r || i. 
      # No network fee is implied in the fake transaction.

      for i in 0..83
        unless @payment_request.real_indices.include? i
          beta[i] = @payment_request.fake_btc_tx_sighash(i)
        end
      end
      # save 84 beta values for Tumbler
      @payment_request.beta_values = beta
      @payment_request.save
    end
      
    # update Tumbler payment request with beta values
    @payment_request.reload
    response= RestClient.patch $TUMBLER_PAYMENT_REQUEST_API_URL, {payment_request: {bob_public_key: @payment_request.bob_public_key, beta_values: "#{@payment_request.beta_values}"}}
    result = JSON.parse(response.body)
    # get c values from result params and put them in an array
    @c_values = Array.new
    @c_values = result["c_values"]
    @payment_request.c_values = @c_values
    @z_values = Array.new
    @z_values = result["z_values"]
    @payment_request.z_values = @z_values
    
    true_count=0
    for i in 0..83
      if @payment_request.beta_values[i] == result["beta_values"][i]
        true_count += 1
      else
        puts @payment_request.beta_values[i]
        puts result["beta_values"][i]
      end
    end
      
    if true_count == 84
      @payment_request.beta_values_sent # update state from "step2" to "step4"
      
      # step6, identify fake set: reveal real indices to Tumbler
      response= RestClient.patch $TUMBLER_PAYMENT_REQUEST_API_URL, {payment_request: {bob_public_key: @payment_request.bob_public_key, real_indices: "#{@payment_request.real_indices}"}}
      result = JSON.parse(response.body)
      
      @payment_request.c_z_values_received # update state from "step4" to "step6"
      @payment_request.real_indices_sent # update state from "step6" to "step7"
      @payment_request.save
      
      # step8, check fake set: check fake epsilon values sent by Tumbler
      @funded_address = @payment_request.hash_address
      @fake_epsilon_values = []
      @fake_epsilon_values = result["fake_epsilon_values"]
      @quotients = []
      @quotients = result["quotients"]
      @payment_request.quotients = @quotients
      @payment_request.save

      # Bob computes sigmai = Dec(epsiloni, ci) for the 42 fake epsilon values
      @sigma = []
      @beta = []
      j = 0
      check_ok = false
      rsa_puzzle_ok = false

      for i in 0..83
        unless @payment_request.real_indices.include? i
          key_hex = @fake_epsilon_values[j]
          iv_hex = $AES_INIT_VECTOR
          key = key_hex.htb
          iv = iv_hex.htb
          #decipher = OpenSSL::Cipher::AES.new(128, :CBC)
          decipher = OpenSSL::Cipher::AES256.new(:CBC)
          decipher.decrypt
          decipher.key = key
          decipher.iv = iv
          @sigma[j] = decipher.update(@c_values[i].from_hex) + decipher.final
          
          # Bob checks that @fake_epsilon_values[j] < n  (RSA modulus)
          e = $TUMBLER_RSA_PUBLIC_EXPONENT
          n = $TUMBLER_RSA_PUBLIC_KEY
          rsa_puzzle_ok = (@fake_epsilon_values[j].to_i(16) < n)
          # Bob checks that RSA puzzle zi = (εi)**e
          rsa_puzzle_ok = rsa_puzzle_ok and (@z_values[i] == mod_pow(@fake_epsilon_values[j].to_i(16),e,n).to_s(16))
          
          # Validate promise @c_values[i]: Bob checks that sigmai is a valid ECDSA signature against PKT and betai
          # @tumbler_key = BTC::Key.new(wif: Figaro.env.tumbler_funding_priv_key)
          # @beta[j] = @payment_request.fake_btc_tx_sighash(i)
          # check_ok = @tumbler_key.verify_ecdsa_signature(@sigma[j], @beta[j].htb)  # result must equal true
          if rsa_puzzle_ok # and check_ok
            j += 1
          else
            puts'There is a problem with Tumblers fake epsilons: Bob should abort protocol.'
            return
          end
        end
      end
      if j == 42 and @payment_request.quotients_ok?
        @payment_request.epsilon_values = @fake_epsilon_values
        @payment_request.fake_epsilons_received # update state from "step7" to "step8"
        @payment_request.quotients_received # update state from "step8" to "step10"
        @payment_request.save
        redirect_to @payment_request, notice: 'Bob steps 2, 3, 4, 6, 8 and 10 completed successfully.'
      else
        redirect_to root_url, alert: 'There is a problem with Tumblers fake epsilons: protocol aborted'
      end
    else
      redirect_to root_url, alert: 'Tumbler seems to have wrong beta values or to be down.'
    end
  end # of bob_step_2
  
  
  def complete
    # Bob checks puzzle solution received from Alice
    @payment_request = PaymentRequest.find(params[:id])
    salt = Figaro.env.tumblebit_salt
    # Bob's blinding factor R in step 12
    blinding_factor = @payment_request.blinding_factor.to_i
    epsilon = @payment_request.solution.to_i(16)/blinding_factor
    puts "Epsilon= #{epsilon.to_s(16)}"
    @payment_request.escrow_tx_broadcasted # transition payment request state from "step10" to "step12"
    @payment_request.puzzle_solution_received # transition payment request state from "step12" to "completed"
    @payment_request.save
    redirect_to @payment_request, notice: 'Puzzle solution was successfully checked by Bob.'
  end
  
  
  def create_spending_tx
    @payment_request = PaymentRequest.find(params[:id]) 
    
    if @payment_request.funded?
      @payment_request.first_unspent_tx
    else
      redirect_to @payment_request, alert: 'Payment request not funded or already spent: no UTXO available.'
    end
  end
  
  
  def broadcast
    @payment_request = PaymentRequest.find(params[:id])
    @payment_request.signed_tx = params[:payment_request][:signed_tx]

    # $PUSH_TX_URL = "https://api.blockcypher.com/v1/btc/main/txs/push"
    uri = URI.parse($PUSH_TX_URL)  # param is "tx"

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new(uri.path, {'Content-Type' =>'application/json'})
    data = {"tx": @payment_request.signed_tx}
    request.body = data.to_json

    response = http.request(request)  # broadcast transaction using $PUSH_TX_URL
    
    post_response = JSON.parse(response.body)
    if post_response["error"]
      puts "Tx broadcast failed: #{post_response["error"]}"
      render 'show_failed_broadcast_tx', alert: "Tx broadcast failed. #{post_response["error"]}. Alternatively: copy the signed transaction below then paste it to https://coinb.in/#broadcast or try the Bitcoin Core sendrawtransaction command."
    else
      puts "Tx was broadcast successfully with Tx ID: #{post_response['tx']['hash']}"
      redirect_to @payment_request, notice: "Tx was broadcast successfully with Tx ID: #{post_response['tx']['hash']}"
    end
  end


  private
 
     def payment_request_params
       params.require(:payment_request).permit(:solution, :r, :blinding_factor, :key_path, :tumbler_public_key, :title, :expiry_date, :tx_hash,:signed_tx, :index, :amount, :confirmations, :aasm_state, :beta_values, :c_values, :epsilon_values, :real_indices => [] )
     end

end