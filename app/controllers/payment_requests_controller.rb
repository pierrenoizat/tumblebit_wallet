class PaymentRequestsController < ApplicationController
  # before_filter :authenticate_user!, :except => [:index]
  # before_filter :payment_request_user?, :except => [:index, :new, :create, :puzzle_list]
  
  include Crypto # module in /lib
  require 'csv'
  require 'btcruby/extensions'

  def index
    @payment_requests = PaymentRequest.where.not(:bob_public_key => nil).page(params[:page]).order(created_at: :asc) 
  end
  
  def new
    @payment_request = PaymentRequest.new
  end
  
  def create
    @payment_request = PaymentRequest.new(payment_request_params)

    if @payment_request.save
      # generate Tumbler ephemeral ECDSA key in Fig 4 step 1 (setup) with path : "6/@payment_request.id"
      @payment_request.tumbler_public_key = BTC::Key.new(wif:@payment_request.tumbler_private_key).compressed_public_key.to_hex
      @payment_request.save
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
    
    unless valid_pubkey?(@payment_request.bob_public_key)
      @notice << "Invalid User Public Key. "
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
  
  
  def create_spending_tx
    @payment_request = PaymentRequest.find(params[:id]) 
    
    if @payment_request.funded?
      @payment_request.first_unspent_tx
    else
      redirect_to @payment_request, alert: 'Payment request not funded or already spent: no UTXO available.'
    end
  end
  
  
  def compute_c_z_values
    # Step 5 of interactions with Bob
    
    @payment_request = PaymentRequest.find(params[:id])
    
    @funding_script = @payment_request.funding_script
    @funded_address = @payment_request.hash_address
    
    if File.exists?("app/views/products/beta_values_#{@funded_address}.csv")
      
    # Tumbler reads the 84 beta values from Bob's CSV file
    # then, Tumbler ECDSA signs each of the 84 beta values to obtain 84 ECDSA signatures sigma
    row_count = 0
    data = open("app/views/products/beta_values_#{@funded_address}.csv").read
    @sigma_values = []

    # key = BTC::Key.new(wif:@payment_request.tumbler_key)  # ECDSA key
    @tumbler_key = BTC::Key.new(wif:"L2dSPKfm998jApkYyF1CoM5zR6rYAassuSbgagMkyB8vxfpiEzFU")
    require 'csv'
    CSV.parse(data) do |row|
      row.each do |beta|
        @sigma_values << @tumbler_key.ecdsa_signature(beta.htb).unpack('H*')[0]
      end
      row_count+=1
    end # do |row| (read input file)
    puts "Number of lines in beta values file: " + row_count.to_s
      
      
    # dump the 84 sigma values to a new csv file for testing
    if File.exists?("app/views/products/sigma_values_#{@funded_address}.csv")
      File.delete("app/views/products/sigma_values_#{@funded_address}.csv") # delete any previous version of file
    end
    
    CSV.open("app/views/products/sigma_values_#{@funded_address}.csv", "ab") do |csv|
      for i in 0..83
        csv << [@sigma_values[i]]
        end
      end # of CSV.open (writing to sigma_values_#{@funded_address}.csv)
      
    # Tumbler then picks 84 random symetric encryption key epsilon (128 bits) and computes 
    # c = AES128(epsilon, sigma) and z = epsilon^^pk where pk is Tumbler RSA public key
    
    e = $TUMBLER_RSA_PUBLIC_EXPONENT
    n = $TUMBLER_RSA_PUBLIC_KEY
    
    @epsilon_values = []
    @c_values = []
    @z_values = []
    for i in 0..83
      data = @sigma_values[i].htb
      # TODO check whether data = @sigma_values[i] works as well
      cipher = OpenSSL::Cipher::AES.new(128, :CBC)
      cipher.encrypt # put cipher in encrypt mode
      key = cipher.random_key  # generate random AES encryption key
      key_hex = key.to_hex
      
      iv = cipher.random_iv # generate random AES initialization vector
      iv_hex = iv.to_hex
      
      k = key_hex + iv_hex  # random symetric encryption key
      while k.size < 64
        k = "0" + k
      end
      key_hex = k.to_s[0..31]
      iv_hex = k.to_s[32..63]
      key = key_hex.htb
      iv = iv_hex.htb
      
      cipher.key = key
      cipher.iv = iv
      encrypted = cipher.update(data) + cipher.final # computes c = encrypts sigma with epsilon

      decipher = OpenSSL::Cipher::AES.new(128, :CBC)
      decipher.decrypt
      
      decipher.key = key
      decipher.iv = iv

      plain = decipher.update(encrypted) + decipher.final
      if data == plain
        @epsilon_values[i] = k
        @c_values[i] = BTC::Data.hex_from_data(encrypted)
        @z_values[i] = mod_pow(k.to_i(16),e,n).to_s(16) # computes z = encrypts epsilon with e, Tumbler's RSA public key (pk)
      else
        redirect_to @puzzle, alert: "Problem with signature encryption: computation of (c,z) pairs aborted."
      end
    end
    
    # dump the 84 (c, z) couples to a new csv file for Bob
    if File.exists?("app/views/products/c_z_values_#{@funded_address}.csv")
      File.delete("app/views/products/c_z_values_#{@funded_address}.csv") # delete any previous version of file
    end
    
    CSV.open("app/views/products/c_z_values_#{@funded_address}.csv", "ab") do |csv|
      for i in 0..83
        csv << [@c_values[i],@z_values[i]]
        end
      end # of CSV.open (writing to c_z_values_#{@funded_address}.csv)
      
      
      # dump the 84 epsilon values to a new csv file (Tumbler keeps them secret for now)
      if File.exists?("app/views/products/epsilon_values_#{@funded_address}.csv")
        File.delete("app/views/products/epsilon_values_#{@funded_address}.csv") # delete any previous version of file
      end

      CSV.open("app/views/products/epsilon_values_#{@funded_address}.csv", "ab") do |csv|
        for i in 0..83
          csv << [@epsilon_values[i]]
          end
        end # of CSV.open (writing to c_z_values_#{@funded_address}.csv)
      
    redirect_to @puzzle, info: "Computation of (c,z) pairs completed successfully."
    
  else
    redirect_to @payment_request, alert: "Tumbler is missing 84 beta values from Bob."
  end
    
  end # of Step 5 of interactions with Bob: compute_c_z_values method
  
  
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
       params.require(:payment_request).permit(:r, :bob_public_key, :tumbler_public_key,:tumbler_private_key, :title, :expiry_date, :tx_hash,:signed_tx, :index, :amount, :confirmations, :real_indices,:beta_values, :c_values, :epsilon_values, :aasm_state )
     end

end