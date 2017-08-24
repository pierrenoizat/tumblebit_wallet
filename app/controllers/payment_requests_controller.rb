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
      @payment.expiry_date = result["expiry_date"]
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
    # if @payment_request.aasm_state == "completed"
    #   @payment_request_payout_tx = @payment_request.payout_tx # force execution of payout_tx method
    # end
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
      flash[:notice] = "Payment request was successfully updated."
      respond_with(@payment_request)
      # render "show"
    else
      redirect_to @payment_request, alert: @notice
    end
  end # of update method
  
  
  def destroy
    @payment_request = PaymentRequest.find_by_id(params[:id])
    if @payment_request.virgin?
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

    if @payment_request.beta_values.blank?
      
      @payment_request.amount = 460000 # amount in satoshis
      
      @tumbler_funded_address = Figaro.env.tumbler_funding_address # 1LUBfiVgeuFRzc7PC1Auw8YAncdewderVg for testing
      @previous_id = @payment_request.first_unspent_tx(@tumbler_funded_address)
      puts "Previous txid = #{@previous_id}"
      puts "Previous index = #{@payment_request.index}"
      puts "Amount = #{( @payment_request.amount.to_f*BTC::COIN ).to_i}"
      beta = []
      @payment_request.real_indices.each do |i|
        beta[i] = @payment_request.real_btc_tx_sighash(i, @previous_id)
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
      @payment_request.escrow_tx_received # transition in state machine from "step1" to "step2"
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

      @tumbler_key=BTC::Key.new(wif:Figaro.env.tumbler_funding_priv_key) # for testing
      puts @tumbler_key.address # 1LUBfiVgeuFRzc7PC1Auw8YAncdewderVg for testing
      j = 0
      check_ok = false
      rsa_puzzle_ok = false

      for i in 0..83
        unless @payment_request.real_indices.include? i
          k = @fake_epsilon_values[j]
          while k.size < 64
            k = "0" + k # padding k with leading zeroes in case of low epsilon value
          end
          key_hex = k[0..31]
          iv_hex = k[32..63]
          key = key_hex.from_hex
          iv = iv_hex.from_hex
          decipher = OpenSSL::Cipher::AES.new(128, :CBC)
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
          @beta[j] = @payment_request.fake_btc_tx_sighash(i)
          check_ok = @tumbler_key.verify_ecdsa_signature(@sigma[j], @beta[j].htb)  # result must equal true
          if rsa_puzzle_ok and check_ok
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
    @payment_request.puzzle_solution_received
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
  

  def sign_tx
    
    require 'btcruby/extensions'
    
    @notice = "Tumblebit payout transaction was successfully signed."
    @payment_request = PaymentRequest.find(params[:id])
    
    @payment_request.confirmations = params[:payment_request][:confirmations]
    @payment_request.tumbler_private_key = params[:payment_request][:tumbler_private_key]
    
    @payment_request.index = params[:payment_request][:index]
    @payment_request.tx_hash = params[:payment_request][:tx_hash]
    @payment_request.amount = params[:payment_request][:amount]

    @previous_index = @payment_request.index.to_i
    @previous_id = @payment_request.tx_hash
    # @refund_address = BTC::Address.parse("16zQaNAg77jco2EDVSsU4bEAq5DgfZPZP4") # my electrum wallet
    @refund_address = BTC::Address.parse(@payment_request.tumbler_refund_address) # tumbler refund address path: "7/@payment_request.id"
    @tumbler_key = BTC::Key.new(wif:@payment_request.tumbler_private_key)
    
    @value = ((@payment_request.amount.to_f * BTC::COIN).to_i - $NETWORK_FEE) # @value is expressed in satoshis
    @funding_script = @payment_request.funding_script
    tx = BTC::Transaction.new
    if @payment_request.expired?
      puts "We are after expiry: require Tumbler key only"

      tx.lock_time = @payment_request.expiry_date.to_i + 1 # time after expiry and before present (in the past)
      tx.add_input(BTC::TransactionInput.new( previous_id: @previous_id,
                                                previous_index: @previous_index,
                                                sequence: 0))
      tx.add_output(BTC::TransactionOutput.new(value: @value, script: @refund_address.script))

      hashtype = BTC::SIGHASH_ALL
      sighash = tx.signature_hash(input_index: 0,
                                    output_script: @funding_script,
                                    hash_type: hashtype)
      tx.inputs[0].signature_script = BTC::Script.new
        
      if e.blank?
        tx.inputs[0].signature_script << (@tumbler_key.ecdsa_signature(sighash) + BTC::WireFormat.encode_uint8(hashtype))
      end
      tx.inputs[0].signature_script << BTC::Script::OP_FALSE # force script execution into checking that expiry was before locktime, then locktime is checked to be in the past as well
      tx.inputs[0].signature_script << @funding_script.data
    else
      puts "Before expiry"

      tx.lock_time = 1471199999 # some time in the past (2016-08-14)
      tx.add_input(BTC::TransactionInput.new( previous_id: @previous_id,
                                                previous_index: @previous_index,
                                                sequence: 0))
      tx.add_output(BTC::TransactionOutput.new(value: @value, script: @refund_address.script))
        
      hashtype = BTC::SIGHASH_ALL
      sighash = tx.signature_hash(input_index: 0,
                                    output_script: @funding_script,
                                    hash_type: hashtype)

      tx.inputs[0].signature_script = BTC::Script.new
      tx.inputs[0].signature_script << BTC::Script::OP_0
      if e.blank?
        data = @tumbler_key.ecdsa_signature(sighash)
        @tumbler_signature = BTC::Data.hex_from_data(data)
        # encrypt Tumbler's signature for Bob with symetric encryption key stored in @payment_request.contract
        cipher = OpenSSL::Cipher::AES.new(128, :CBC)
        cipher.encrypt
        if @payment_request.contract.blank?
          key = cipher.random_key  # generate random AES encryption key
          key_hex = key.to_hex
          puts key_hex
          
          iv = cipher.random_iv # generate random AES initialization vector
          iv_hex = iv.to_hex
          
          contract = key_hex + iv_hex  # epsilon, 128-bit key + 128-bit iv, total 256 bits
            # TODO Encrypt epsilon before storing in database
          @payment_request.update(contract: contract) # store key + iv in @payment_request contract attribute
        else
          contract = @payment_request.contract
        end
          
        key_hex = contract.to_s[0..31]
        iv_hex = contract.to_s[32..63]
        key = key_hex.from_hex
        iv = iv_hex.from_hex
          
        cipher.key = key
        cipher.iv = iv
        encrypted = cipher.update(data) + cipher.final

        decipher = OpenSSL::Cipher::AES.new(128, :CBC)
        decipher.decrypt
        decipher.key = key
        decipher.iv = iv

        plain = decipher.update(encrypted) + decipher.final
        if data == plain
          @tumbler_encrypted_signature = BTC::Data.hex_from_data(encrypted)
        else
          @tumbler_encrypted_signature = "Problem with signature encryption."
        end
          
        # generate puzzle y by encrypting encryption key (@payment_request.contract) with Tumbler RSA public key
        m = contract.to_i(16)
        modulus = $TUMBLER_RSA_PUBLIC_KEY
        pubexp = $TUMBLER_RSA_PUBLIC_EXPONENT
        puzzle = mod_pow(m,pubexp,modulus) # epsilon^e mod modulus
        puts "puzzle: %x" % puzzle

        # puzzle solution
        d = Figaro.env.tumbler_rsa_private_key.to_i(16)
        solution = mod_pow(puzzle,d,modulus) # puzzle^d mod modulus
        puts solution
        puts contract.to_s # solution should be equal to contract
          
        if @payment_request.puzzles.blank?
          @puzzle = Puzzle.create(:payment_request_id => @payment_request.id, :y => puzzle, :encrypted_signature => @tumbler_encrypted_signature)
        else
          @puzzle = @payment_request.puzzles.last
        end
      end
        
      @redeem_script = @funding_script.data.to_hex
    end

    @payment_request.signed_tx = tx.to_s
    
    s = @notice
    if e
      s += e.message
    end
    unless s == "Tumblebit payout transaction was successfully signed."
      redirect_to @payment_request, alert: s
    else
      flash[:notice] = s
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