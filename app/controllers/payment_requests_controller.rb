class PaymentRequestsController < ApplicationController
  # before_filter :authenticate_user!, :except => [:index]
  # before_filter :payment_request_user?, :except => [:index, :new, :create, :puzzle_list]
  
  include Crypto # module in /lib
  require 'csv'
  require 'btcruby/extensions'

  def index
    @payment_requests = PaymentRequest.where.not(:key_path => nil).page(params[:page]).order(created_at: :asc) 
  end
  
  
  def new
    @payment_request = PaymentRequest.new
  end
  
  
  def create
    @payment_request = PaymentRequest.new(payment_request_params)
    @payment_request.expiry_date  ||= Time.now.utc  # will set the default value only if it's nil
    real_indices = []
    prng = Random.new
    while real_indices.count < 42
      j = prng.rand(0..83)
      unless real_indices.include? j
        real_indices << j
      end
    end
    @payment_request.real_indices ||= real_indices.sort

    salt = Figaro.env.tumblebit_salt
    index = (salt.to_i + prng.rand(0..99999)) % 0x80000000
    @payment_request.key_path = "1/#{index}"

    if @payment_request.save
      redirect_to edit_payment_request_path(@payment_request), notice: 'Payment request was successfully created.'
    else
      alert_string = ""
      @payment_request.errors.full_messages.each do |msg|
        msg += ". "
        alert_string += msg 
      end
      redirect_to new_payment_request_path, alert: alert_string
    end
  end
  

  def edit
    @payment_request = PaymentRequest.find(params[:id])
  end
  

  def update
    @payment_request = PaymentRequest.find(params[:id])
    @payment_request.update_attributes(payment_request_params)
    @notice = ""
    
    unless valid_pubkey?(@payment_request.tumbler_public_key)
      @notice << "Invalid Tumbler Public Key. "
    end
        
    if @notice.blank?
      render "show"
    else
      redirect_to @payment_request, alert: @notice
    end
  end # of update method
  
  
  def show
    @payment_request = PaymentRequest.find(params[:id])
  end # of show method
  
  
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
    # Steps 2 and 3 in Tumbler-Bob interactions, performed by Bob
    # Bob generates 42 “real” payout addresses (keeps them secret for now) and prepares 42 distinct “real” transactions.
    @payment_request = PaymentRequest.find(params[:id])
    @funded_address = @payment_request.hash_address
    @notice = ""
    unless @payment_request.beta_values.blank?
      @notice = 'Beta values already exists.'
      # dump the 84 beta values to a new csv file for testing
      if File.exists?("app/views/products/beta_values_#{@funded_address}.csv")
        File.delete("app/views/products/beta_values_#{@funded_address}.csv") # delete any previous version of file
      end

      CSV.open("app/views/products/beta_values_#{@funded_address}.csv", "ab") do |csv|
        for i in 0..83
          csv << [@payment_request.beta_values[i]]
          end
        end # of CSV.open (writing to sigma_values_#{@funded_address}.csv)
    else
      
      @payment_request.amount = 240800 # amount in satoshis

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
    end
    if @notice.blank?
      @payment_request.escrow_tx_received # transition in state machine
      @payment_request.beta_values_sent
      @payment_request.save
      redirect_to @payment_request, notice: 'Transactions were successfully created by Bob.'
    else
      redirect_to root_url, notice: @notice
    end
  end # of bob_step_2
  
  
  def bob_step_8
    # For all fake epsilon values provided by Tumbler, Bob checks that sigmai = Dec(epsiloni, ci) 
    # and ECDSA-verifies the signature against PKT and betai = sighashi.
    # Bob aborts the protocol if any check fails.
    @payment_request = PaymentRequest.find(params[:id])
    @funded_address = @payment_request.hash_address
    data = open("app/views/products/fake_epsilon_values_#{@funded_address}.csv").read
    @fake_epsilon_values = []
    j = 0
    CSV.parse(data) do |row|
      fake_epsilon_array = []
      row.each do |f|
        fake_epsilon_array << f
        @fake_epsilon_values[j] = fake_epsilon_array[0]
      end
      j+=1
    end # do |row| (read input file)
    puts "Number of fake epsilon values in file: " + j.to_s
    
    data = open("app/views/products/c_z_values_#{@funded_address}.csv").read
    @c_values = []
    @z_values = []
    j = 0
    CSV.parse(data) do |row|
      c_z_array = []
      row.each do |f|
        c_z_array << f
        @c_values[j] = c_z_array[0]
        @z_values[j] = c_z_array[1]
      end
      j+=1
    end # do |row| (read input file)
    puts "Number of c values in file: " + j.to_s
    # Bob computes sigmai = Dec(epsiloni, ci) for the 42 fake epsilon values
    @sigma = []
    @beta = []
    j = 0
    # @r = @payment_request.r.to_i

    @tumbler_key=BTC::Key.new(public_key:BTC.from_hex(@payment_request.tumbler_public_key))
    puts @tumbler_key.address
    @result = false
    
    for i in 0..83
      unless @payment_request.real_indices.include? i
        k = @fake_epsilon_values[j]
        while k.size < 64
          k = "0" + k # padding with leading zeroes in case of low epsilon value
        end
        puts "fake epsilon: #{k}"
        key_hex = k[0..31]
        iv_hex = k[32..63]
        key = key_hex.from_hex
        iv = iv_hex.from_hex
        decipher = OpenSSL::Cipher::AES.new(128, :CBC)
        decipher.decrypt
        decipher.key = key
        decipher.iv = iv
        @sigma[j] = decipher.update(@c_values[i].from_hex) + decipher.final
        puts "fake sigma value = #{@sigma[j].unpack('H*')[0]}"
        puts "c value = #{@c_values[i]}"
        
        # Bob checks that sigmai is a valid ECDSA signature against PKT and betai
        @beta[j] = @payment_request.fake_btc_tx_sighash(i)
        puts "beta = #{@beta[j]}"
        @result = @tumbler_key.verify_ecdsa_signature(@sigma[j], @beta[j].htb)  # result must equal true
        if @result
          j += 1
        else
          puts j
          redirect_to @payment_request, alert: 'There is a problem with Tumblers fake epsilons: Bob should abort protocol.'
          return
        end
      end
    end
    if j == 42
      redirect_to @payment_request, notice: 'Tumblers fake epsilons were successfully checked by Bob.'
    end
  
  end # of bob_step_8
  
  
  def bob_step_10
    # In step 10, Bob computes zj1*(q2)pk = (epsilonj2)pk and checks that zj2 = zj1*(q2)pk
    # If any check fails, Bob aborts the protocol.
    # If no fail, Tumbler is very likely to have sent validly formed zi values.
    @payment_request = PaymentRequest.find(params[:id])
    e = $TUMBLER_RSA_PUBLIC_EXPONENT
    n = $TUMBLER_RSA_PUBLIC_KEY
    data = open("app/views/products/quotient_values_#{@payment_request.hash_address}.csv").read
    @quotient = []
    @num = []
    @denum = []
    j = 0
    CSV.parse(data) do |row|
      quotient_array = []
      row.each do |f|
        quotient_array << f
        @quotient[j] = quotient_array[0].to_i
      end
      j+=1
    end # do |row| (read input file)
    puts "Number of quotient values in file: " + j.to_s
    
    data = open("app/views/products/c_z_values_#{@payment_request.hash_address}.csv").read
    @z_values = []
    j = 0

    CSV.parse(data) do |row|
      c_z_array = []
      row.each do |zeta|
        c_z_array << zeta
      end
      # @z_values[j] = c_z_array[1].to_i(16)
      @z_values[j] = c_z_array[1]
      j+=1
    end # do |row| (read input file)
    puts "Number of z values in file: " + j.to_s
    
    @real_z_values = []
    for i in 0..83
      if @payment_request.real_indices.include? i
        @real_z_values << @z_values[i]
      end
    end
    puts "Number of real z values : " + @real_z_values.count.to_s

    puts "check that z2 = z1*(q2)^pk mod n"
    # check that z2 = z1*(q2)^pk mod n :

    j = 0
    for i in 0..40
      z2 = @real_z_values[i+1].to_i(16)
      z1 = @real_z_values[i].to_i(16)
      q2 = @quotient[i]
      puts z2.to_s(16)
      puts z1.to_s(16)
      puts q2
      if (z2 == (z1*mod_pow(q2, e, n) % n))
        j += 1
      else
        puts "Failed test, should be zero:" + ((z2 - z1*mod_pow(q2, e, n)) % n).to_s
      end
      puts j
    end
    
    if j == 41
      # TODO: Bob step 12
      # Bob picks random R and keeps it secret
      # Bob sets z= zj1 = (epsilonj1)**e = @real_z_values[0] and sends y = z*(R**e)  to Alice
       y = @real_z_values[0].to_i(16)*mod_pow(@payment_request.r.to_i, e, n) % n
       @payment_request.y  = y.to_s(16)
       @payment_request.save
      redirect_to @payment_request, notice: 'Tumblers RSA quotients were successfully checked by Bob.'
    else
      puts j
      redirect_to @payment_request, alert: 'There is a problem with Tumblers RSA quotients: Bob should abort protocol.'
    end
    
  end # of bob_step_10
  
  
  def create_puzzle_z
    
    @payment_request = PaymentRequest.find(params[:id])
    if @payment_request_funded
      @payment_request.first_unspent_tx
    else
      redirect_to @payment_request, alert: 'Contract not funded or already spent: no UTXO available.'
    end
    
    if @payment_request.puzzles.blank?
      @puzzle = Puzzle.create(:payment_request_id => @payment_request.id)
    else
      @puzzle = @payment_request.puzzles.last
    end
     
    @tumbler_key = @payment_request.tumbler_key # wif format string
    @previous_index = @payment_request.index.to_i  # 
    @previous_id = @payment_request.tx_hash

    tx = BTC::Transaction.new
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
      while contract.size < 64
        contract = "0" + contract
      end
      
      key_hex = contract.to_s[0..31]
      iv_hex = contract.to_s[32..63]
      key = key_hex.htb # was key_hex.from_hex
      iv = iv_hex.htb
      
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
    fee = 0.00015 # approx. 10 cts when 1 BTC = 700 EUR
    @previous_index = @payment_request.index.to_i
    @previous_id = @payment_request.tx_hash
    # @refund_address = BTC::Address.parse("16zQaNAg77jco2EDVSsU4bEAq5DgfZPZP4") # my electrum wallet
    @refund_address = BTC::Address.parse(@payment_request.tumbler_refund_address) # tumbler refund address path: "7/@payment_request.id"
    @tumbler_key = BTC::Key.new(wif:@payment_request.tumbler_private_key)
    
    @value = (@payment_request.amount.to_f - fee) * BTC::COIN # @value is expressed in satoshis
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
  
  
  def puzzle_list
    @payment_requests = PaymentRequest.all.page(params[:page])
  end


  private
 
     def payment_request_params
       params.require(:payment_request).permit(:r, :key_path, :tumbler_public_key, :title, :expiry_date, :tx_hash,:signed_tx, :index, :amount, :confirmations, :real_indices,:beta_values, :c_values, :epsilon_values, :aasm_state )
     end

end