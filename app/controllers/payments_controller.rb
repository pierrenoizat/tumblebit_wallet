class PaymentsController < ApplicationController
  # skip_before_action :verify_authenticity_token
  include Crypto # module in /lib
  # include Http # module in /lib
  # require 'csv'
  require 'btcruby/extensions'
  # require 'mechanize'
  require 'rest-client'
  # require 'digest'
  
  def index
    @payments = Payment.where.not(:key_path => nil).page(params[:page]).order(created_at: :desc)
  end
  
  
  def new
    @payment = Payment.new
    # @payment.expiry_date ||= Time.now.utc  # will set the default value only if it's nil
    real_indices = []
    prng = Random.new
    while real_indices.count < 15
      j = prng.rand(0..299)
      unless real_indices.include? j
        real_indices << j
      end
    end
    @payment.real_indices = real_indices.sort
    
    salt = Figaro.env.tumblebit_salt
    index = (salt.to_i + prng.rand(0..99999)) % 0x80000000
    @payment.key_path = "1/#{index}"
  end
  
  
  def create
    @payment = Payment.new(payment_params)
    
    # create @payment on Tumbler side
    response= RestClient.post $TUMBLER_PAYMENT_API_URL, {payment: {alice_public_key: @payment.alice_public_key}}
    result = JSON.parse(response.body)
    # get Tumbler key in http response and save it to @payment in Alice wallet
    @payment.tumbler_public_key = result["tumbler_public_key"]
    @payment.expiry_date = result["expiry_date"]
    
    if @payment.save
      flash[:notice] = "Payment was successfully created"
      render "show"
    else
      flash[:notice] = "There was a problem with this payment creation."
      redirect_to payments_url
    end
  end
  
  
  def show
    @payment = Payment.find(params[:id])
    if @payment.aasm_state == "step8"
      alice_step_11
    end
  end
  
  
  def edit
    @payment = Payment.find(params[:id])
  end
  
  
  def update
    @payment = Payment.find(params[:id])
    if @payment.update_attributes(payment_params)
      if @payment.y and @payment.aasm_state == "initiated"
        @payment.y_received # update state from "initiated" to "step1"
        @payment.save
      end
      if @payment.aasm_state == "step1"
        alice_step_1
      else
        flash[:notice] = "Payment successfully updated."
        render "show"
      end
    else
      flash[:notice] = "There was a problem with this payment."
      redirect_to payments_url
    end
  end
  
  
  def destroy
    @payment = Payment.find_by_id(params[:id])
    @payment.destroy
    redirect_to payments_path, notice: 'Payment was successfully deleted.'
  end
  
  
  def alice_step_1
    # Fig. 3, steps 1,2,3,5,7
    # Alice creates 300 values for Tumbler, mixing 15 real values with 285 fake values
    @payment = Payment.find(params[:id])

    if @payment.real_indices.blank?
      real_indices = []
      prng = Random.new
      while real_indices.count < 15
        j = prng.rand(0..299)
        unless real_indices.include? j
          real_indices << j
        end
      end
      @payment.real_indices = real_indices.sort
      @payment.save # save indices of real values to @payment.real_indices
    end

    e = $TUMBLER_RSA_PUBLIC_EXPONENT
    n = $TUMBLER_RSA_PUBLIC_KEY

    salt=Random.new.bytes(128).unpack('H*')[0] # 1024-bit random integer
    puts "Salt: #{salt}"
    @r_values = []
    @ro_values = []

    for i in 0..299  # create 300 blinding factors
      if @payment.real_indices.include? i
        @r_values[i]=Random.new.bytes(10).unpack('H*')[0] # "8f0722a18b63d49e8d9a", size = 20 hex char, 80 bits, 10 bytes
        @ro_values[i] = nil
      else
        # salt is same size as y, otherwise Tumbler can easily tell real values from fake values based on the size of s
        @r_values[i]=(Random.new.bytes(10).unpack('H*')[0].to_i(16)*salt.to_i(16) % n).to_s(16)
        @ro_values[i] = @r_values[i]
      end
    end

    @beta_values = []

    # first, compute 15 real beta values
    if @payment.y
      p = @payment.y.to_i(16) # y = epsilon^^pk,received from Bob

      for i in 0..299
        m = @r_values[i].to_i(16)
        if @payment.real_indices.include? i
          b = mod_pow(m,e,n)
          beta_value = (p*b) % n
        else
          beta_value = mod_pow(m,e,n)
        end
        @beta_values[i] = beta_value.to_s(16)
      end
      
      response= RestClient.patch $TUMBLER_PAYMENT_API_URL, {payment: {alice_public_key: @payment.alice_public_key, beta_values: "#{@beta_values}"}}
      result = JSON.parse(response.body)
      @payment.expiry_date = result["expiry_date"]
      # get c values from result params and put them in an array
      @c_values = Array.new
      @c_values = result["c_values"]
      @payment.c_values = @c_values

      # get h values from result params and put them in an array
      @h_values = Array.new
      @h_values = result["h_values"]
      @payment.h_values = @h_values

      @payment.beta_values = @beta_values
      # @payment.ro_values = @ro_values,  no longer an attribute, now a model method
      @payment.r_values = @r_values # 15 real r values to be revealed to Tumbler after step 8
      @payment.beta_values_sent # update state from "step1" to "step3"
      @payment.c_h_values_received # update payment state from "step3" to "step5"
      @payment.save
    else
      raise "Before computing beta values, Alice must get y from Bob."
    end

    # send real indices and 285 (fake) ro values to Tumbler
    # ro values are a 300-element array with 15 nil values in it.
    response= RestClient.patch $TUMBLER_PAYMENT_API_URL, {payment: {alice_public_key: @payment.alice_public_key, real_indices: "#{@payment.real_indices}",ro_values: "#{@ro_values}"}}
    result = JSON.parse(response.body)

    # Fig 3, step 7
    # For 285 fake indices, Alice verifies now that h = H(k), computes s = Dec(k,c) and verifies also that s = ro
    @fake_k_values = Array.new
    @fake_k_values = result["fake_k_values"]

    true_count = 0
    j = 0
    for i in 0..299
      unless @payment.real_indices.include? i
        if @payment.h_values[i] == @fake_k_values[j].ripemd160.to_hex
          true_count += 1
        end
        j += 1
      end
    end

    if true_count != 285
      raise 'Check fake k values failed: mismatch between h and H(k) values.'
    end
    # Alice now computes s = Dec(k,c) and verifies that s^^pk = beta

    @s_values = []
    j = 0
    for i in 0..299
      unless @payment.real_indices.include? i
        key_hex = @fake_k_values[j]
        c = @payment.c_values[i]
        decipher = OpenSSL::Cipher::AES256.new(:CBC)
        decipher.decrypt
        iv_hex = $AES_INIT_VECTOR
        key = key_hex.htb
        iv = iv_hex.htb
        decipher.key = key
        decipher.iv = iv
        @s_values[i] =  decipher.update(BTC::Data.data_from_hex(c)) + decipher.final
        j += 1
      end
    end

    true_count = 0
    for i in 0..299
      unless @payment.real_indices.include? i
        if (@payment.ro_values[i] == @s_values[i])  # verify s = ro (fake values)
          true_count += 1
        end
      end
    end

    if true_count != 285
        puts "Mismatch between fake s and ro values."
        raise 'Tumblebit protocol session aborted: mismatch between fake s and ro values'
    end
    
    # Post transaction Tpuzzle offering 1 bitcoin within timewindow tw1
    # under condition “the fulfilling transaction is signed by T and has preimages of hj ∀j ∈ R”
    
    @payment.k_values = @fake_k_values
    @payment.fake_k_values_checked # update state from "step5" to "step7"
    @payment.y_value_sent # update state from "step7" to "step8"
    @payment.save
    
    # send y and real r_values to Tumbler so he can validate y: Tumbler verifies for all j ∈ R βj=y·(rj)e mod n
    response= RestClient.patch $TUMBLER_PAYMENT_API_URL, {payment: {alice_public_key: @payment.alice_public_key, y: "#{@payment.y}",r_values: "#{@payment.r_values}"}}
    result = JSON.parse(response.body)
    
    flash[:notice] = "Payment successfully updated: step 8 completed. Post transaction Tpuzzle"
    render "show"
    
    
  end # of method alice_step_1
  
  
  def alice_step_11
    # Learn kj from Tsolve spending Tpuzzle funded by Alice in alice_step_7
    # @payments = Payment.all
    @payment = Payment.find(params[:id])

    # url_string = $BLOCKR_RAW_TX_URL + "#{@payment.first_spending_tx_hash_unconfirmed}"
    # url_string = $BLOCKCHAIN_RAW_TX_URL + "#{@payment.first_spending_tx_hash_unconfirmed}" +"?format=hex"
    url_string = $BLOCKCHAIN_RAW_TX_URL + "#{@payment.first_spending_tx_hash}" +"?format=hex"
    @agent = Mechanize.new
    begin
      page = @agent.get url_string
    rescue Exception => e
      page = e.page
    end
    data = page.body
    # result = JSON.parse(data)
    # @transaction = BTC::Transaction.new(hex: result['data']['tx']['hex'])
    if data.size >= 64
      @transaction = BTC::Transaction.new(hex: data)
      @words = @transaction.dictionary['in'][0]['scriptSig']['asm'].split(/\W+/) # array of real k values revealed by Tumbler
      @real_k_values = []
      for i in 1..15
			  @real_k_values[i-1] = @words[16-i].scan(/../).map { |x| x.hex.chr }.join # convert to hex string
		  end
      # Decrypt cj to sj = Hprg(kj) ⊕ cj
      # Decrypt 15 real cj to sj = Hprg(kj) ⊕ cj 
      @real_s_values = []
      @real_c_values = @payment.real_c_values
      # Tumbler picked 15 real random symetric encryption key k (128 bits) and computed 
      # c = Enc(k, s) and h = H(k)
      true_count = 0
      e = $TUMBLER_RSA_PUBLIC_EXPONENT
      n = $TUMBLER_RSA_PUBLIC_KEY
      for i in 0..14
        decipher = OpenSSL::Cipher::AES256.new(:CBC)
        decipher.decrypt
      
        key_hex = @real_k_values[i]
        iv_hex = $AES_INIT_VECTOR
        key = key_hex.htb
        iv = iv_hex.htb
        decipher.key = key
        decipher.iv = iv
        encrypted = @real_c_values[i].htb
        @real_s_values[i] = decipher.update(encrypted) + decipher.final # plain
        if (@payment.real_beta_values[i] == mod_pow(@real_s_values[i].to_i(16),e,n).to_s(16))  # verify s**e = beta mod n
          true_count += 1
        end
      end
    
      # Obtain solution sj/rj mod n
      # which is y**d mod N.
      @payment.solution = ((@real_s_values[0].to_i(16)/@payment.real_r_values[0].to_i(16)) % n).to_s(16)
      if true_count == 15
        if @payment.aasm_state == "step8"
          @payment.real_k_values_obtained # update state from "step8" to "completed"
        end
        @payment.save
        flash[:notice] = "Payment successfully completed (step 11): puzzle solution obtained"
        render "show"
      else
        redirect_to payments_url, alert: "Mismatch between real s and beta values."
      end
    else # data.size != 64, no tx spending from P2SH address yet.
      # redirect_to payments_url, alert: "Tumbler has not been paid yet. Please try again later."
      # flash[:alert] = "Tumbler has not been paid yet. Please pay the escrow address and try again."
      render "show"
    end
    
  end # of alice_step_11
  
  
  def alice_step_9
    # Tumbler gets y and r_values file from Alice
    # Tumbler verifies real beta_values = y·(r)^^e mod n for real r values
    # If not, abort.
    # if all real beta values unblind to y, Tumbler post transaction Tsolve containing 15 real k values
  end


  private
 
     def payment_params
       params.require(:payment).permit(:solution, :title, :y ,:key_path, :tumbler_public_key, :expiry_date, :aasm_state, :r_values => [], :beta_values => [], :k_values => [], :real_indices => [], :c_values => [], :h_values => [])
     end

end