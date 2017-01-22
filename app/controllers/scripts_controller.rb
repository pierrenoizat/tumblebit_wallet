class ScriptsController < ApplicationController
  before_filter :authenticate_user!, :except => [:index]
  before_filter :script_user?, :except => [:index, :new, :create, :puzzle_list]
  
  require 'btcruby/extensions'

  def index
    @scripts = Script.page(params[:page]).order(created_at: :asc) 
  end
  
  def new
    @script = Script.new
  end
  
  def create
      @script = Script.new(script_params)
      if current_user
        @script.user_id = current_user.id
      else
        if current_client
          @script.client_id = current_client.id
        else
          redirect_to new_script_path, alert: "Contract could not be created: please sign in first."
        end
      end
      if @script.save
        # generate Tumbler ephemeral ECDSA key in Fig 4 step 1 (setup)
        @puzzle = Puzzle.create(:script_id => @script.id)
        # if @script.tumbler_key.blank?
          key = @puzzle.generate_bitcoin_key_pair # path : @puzzle.script_id/id
          # @script.tumbler_key = BTC::Key.new(wif:key.to_wif)
          @script.tumbler_key = key.to_wif # TODO encrypt using Tumbler RSA public key before saving.
          @script.save
        # end

        # get corresponding public key
        key = BTC::Key.new(wif:@script.tumbler_key)
        @xpub = key.compressed_public_key.to_hex
        
        redirect_to edit_script_path(@script), notice: 'Contract was successfully created.'
       else
        alert_string = ""
        @script.errors.full_messages.each do |msg|
          msg += ". "
          alert_string += msg 
        end
        redirect_to new_script_path, alert: alert_string
      end
  end
  

  def edit
    @script = Script.find(params[:id])
    
    case @script.category
        
      when "tumblebit_puzzle"
        if PublicKey.where(:script_id => @script.id, :name => "Alice").last
          @script.alice_pub_key_1 = PublicKey.where(:script_id => @script.id, :name => "Alice").last.compressed
        else
          @script.alice_pub_key_1 = ""
        end
        if PublicKey.where(:script_id => @script.id, :name => "Tumbler").last
          @script.oracle_1_pub_key = PublicKey.where(:script_id => @script.id, :name => "Tumbler").last.compressed
        else
          @script.oracle_1_pub_key = ""
        end
        @script.secret_k1 = @script.secret_k1 || "a"
        @script.secret_k2 = @script.secret_k2 || "b"
        @script.secret_k3 = @script.secret_k3 || "c"
        @script.secret_k4 = @script.secret_k4 || "d"
        @script.secret_k5 = @script.secret_k5 || "e"
        @script.secret_k6 = @script.secret_k6 || "f"
        @script.secret_k7 = @script.secret_k7 || "g"
        @script.secret_k8 = @script.secret_k8 || "h"
        @script.secret_k9 = @script.secret_k9 || "i"
        @script.secret_k10 = @script.secret_k10 || "j"
        @script.secret_k11 = @script.secret_k11 || "k"
        @script.secret_k12 = @script.secret_k12 || "l"
        @script.secret_k13 = @script.secret_k13 || "m"
        @script.secret_k14 = @script.secret_k14 || "n"
        @script.secret_k15 = @script.secret_k15 || "o"
        
        render :template => 'scripts/edit_tumblebit_puzzle'
        
      when "tumblebit_escrow_contract"
        
        cipher = OpenSSL::Cipher::AES.new(128, :CBC)
        cipher.encrypt
        if @script.contract.blank?
          key = cipher.random_key  # generate random AES encryption key
          key_hex = key.to_hex
          puts key_hex
        
          iv = cipher.random_iv # generate random AES initialization vector
          iv_hex = iv.to_hex
        
          @script.contract = key_hex + iv_hex # store key + iv in @script contract attribute
        end
        
        if PublicKey.where(:script_id => @script.id, :name => "Bob").last
          @script.bob_pub_key_1 = PublicKey.where(:script_id => @script.id, :name => "Bob").last.compressed
        else
          @script.bob_pub_key_1 = ""
        end
        if @script.tumbler_key
          key = BTC::Key.new(wif: @script.tumbler_key)
          @script.oracle_1_pub_key = key.compressed_public_key.to_hex
        else
          @script.oracle_1_pub_key = ""
        end
        render :template => 'scripts/edit_tumblebit_escrow_contract' 
        
    end
  end
  

  def update
    @script = Script.find(params[:id])
    @script.update_attributes(script_params)
    @notice = ""
    case @script.category
          
        when "tumblebit_puzzle"
          
          if valid_pubkey?(@script.alice_pub_key_1)
            @public_key = PublicKey.new(:script_id => @script.id, :compressed => @script.alice_pub_key_1, :name => "Alice")
            @public_key.save
          else
            @notice << "Invalid User Public Key. "
          end
          if valid_pubkey?(@script.oracle_1_pub_key)
            @public_key = PublicKey.new(:script_id => @script.id, :compressed => @script.oracle_1_pub_key, :name => "Tumbler")
            @public_key.save
          else
            @notice << "Invalid Tumbler Public Key. "
          end
          if PublicKey.where(:script_id => @script.id, :name => "Alice").last
            @script.alice_pub_key_1 = PublicKey.where(:script_id => @script.id, :name => "Alice").last.compressed
          else
            @script.alice_pub_key_1 = ""
          end
          if PublicKey.where(:script_id => @script.id, :name => "Tumbler").last
            @script.oracle_1_pub_key = PublicKey.where(:script_id => @script.id, :name => "Tumbler").last.compressed
          else
            @script.oracle_1_pub_key = ""
          end
          
          
          if @script.contract.blank?
            @script.secret_k1 = params[:script][:secret_k1] || "a"
            @script.secret_k2 = params[:script][:secret_k2] || "b"
            @script.secret_k3 = params[:script][:secret_k3] || "c"
            @script.secret_k4 = params[:script][:secret_k4] || "d"
            @script.secret_k5 = params[:script][:secret_k5] || "e"
            @script.secret_k6 = params[:script][:secret_k6] || "f"
            @script.secret_k7 = params[:script][:secret_k7] || "g"
            @script.secret_k8 = params[:script][:secret_k8] || "h"
            @script.secret_k9 = params[:script][:secret_k9] || "i"
            @script.secret_k10 = params[:script][:secret_k10] || "j"
            @script.secret_k11 = params[:script][:secret_k11] || "k"
            @script.secret_k12 = params[:script][:secret_k12] || "l"
            @script.secret_k13 = params[:script][:secret_k13] || "m"
            @script.secret_k14 = params[:script][:secret_k14] || "n"
            @script.secret_k15 = params[:script][:secret_k15] || "o"
            secret_k = Array[@script.secret_k1,@script.secret_k2,@script.secret_k3,@script.secret_k4,@script.secret_k5,@script.secret_k6,
                      @script.secret_k7,@script.secret_k8,@script.secret_k9,@script.secret_k10,@script.secret_k11,
                      @script.secret_k12,@script.secret_k13,@script.secret_k14,@script.secret_k15]
                      
                      
            k = Array.new
            string = ""
            for i in 0..14
              unless secret_k[i].blank?
                k[i] = secret_k[i].ripemd160
              end
            end
            for i in 0..14
              unless k[i].blank?
                string += k[i].ripemd160.to_hex
              end
            end
            if string.size == 600
              @script.update(contract: string) # string is concatenation of hi = ripemd(ki), i in 0..14
            end
          end
          
          if @notice.blank?
            render 'show_tumblebit_puzzle'
          else
            redirect_to @script, alert: @notice
          end
        
      when "tumblebit_escrow_contract"
        if valid_pubkey?(@script.bob_pub_key_1)
          @public_key = PublicKey.new(:script_id => @script.id, :compressed => @script.bob_pub_key_1, :name => "Bob")
          @public_key.save
        else
          @notice << "Invalid User Public Key. "
        end

        if PublicKey.where(:script_id => @script.id, :name => "Bob").last
          @script.bob_pub_key_1 = PublicKey.where(:script_id => @script.id, :name => "Bob").last.compressed
        else
          @script.bob_pub_key_1 = ""
        end
        
        if @script.tumbler_key
          key = BTC::Key.new(wif: @script.tumbler_key)
          @script.oracle_1_pub_key = key.compressed_public_key.to_hex
        else
          @script.oracle_1_pub_key = ""
        end
        
        if @notice.blank?
          render 'show_tumblebit_escrow_contract'
        else
          redirect_to @script, alert: @notice
        end
        
    end # of case statement

  end # of update method
  
  

  def show
    @script = Script.find(params[:id])
    @public_keys = @script.public_keys
    case @script.category
        
      when "tumblebit_puzzle"
        if PublicKey.where(:script_id => @script.id, :name => "Alice").last
          @script.alice_pub_key_1 = PublicKey.where(:script_id => @script.id, :name => "Alice").last.compressed
        else
          @script.alice_pub_key_1 = ""
        end
        if PublicKey.where(:script_id => @script.id, :name => "Tumbler").last
          @script.oracle_1_pub_key = PublicKey.where(:script_id => @script.id, :name => "Tumbler").last.compressed
        else
          @script.oracle_1_pub_key = ""
        end
        
        render 'show_tumblebit_puzzle'
        
      when "tumblebit_escrow_contract"
        if PublicKey.where(:script_id => @script.id, :name => "Bob").last
           @script.bob_pub_key_1 = PublicKey.where(:script_id => @script.id, :name => "Bob").last.compressed
        else
           @script.bob_pub_key_1 = ""
        end
       
       unless @script.tumbler_key.blank?
         key = BTC::Key.new(wif:@script.tumbler_key)
         @xpub = key.compressed_public_key.to_hex
         puts @script.tumbler_key
       end
        render 'show_tumblebit_escrow_contract'
        
    end # of case statement
    
  end # of show method
  
  
  def destroy
    @script = Script.find_by_id(params[:id])
    if @script.virgin?
      @script.public_keys.each do |public_key|
        public_key.destroy
      end
      @script.destroy
      redirect_to scripts_path, notice: 'Contract was successfully deleted.'
    else
      redirect_to @script, alert: 'Contract was funded, it cannot be deleted.'
    end
  end
  
  
  def create_spending_tx
    @script = Script.find(params[:id])
    
    case @script.category
      
      when "tumblebit_puzzle"
        if PublicKey.where(:script_id => @script.id, :name => "Alice").last
          @script.alice_pub_key_1 = PublicKey.where(:script_id => @script.id, :name => "Alice").last.compressed
        else
          @script.alice_pub_key_1 = ""
        end
        if PublicKey.where(:script_id => @script.id, :name => "Tumbler").last
          @script.oracle_1_pub_key = PublicKey.where(:script_id => @script.id, :name => "Tumbler").last.compressed
        else
          @script.oracle_1_pub_key = ""
        end
        
      when "tumblebit_escrow_contract"
        if PublicKey.where(:script_id => @script.id, :name => "Bob").last
          @script.bob_pub_key_1 = PublicKey.where(:script_id => @script.id, :name => "Bob").last.compressed
        else
          @script.bob_pub_key_1 = ""
        end
        if PublicKey.where(:script_id => @script.id, :name => "Tumbler").last
          @script.oracle_1_pub_key = PublicKey.where(:script_id => @script.id, :name => "Tumbler").last.compressed
        else
          @script.oracle_1_pub_key = ""
        end  
    end
    
    if @script.funded?
      @script.first_unspent_tx
    else
      redirect_to @script, alert: 'Contract not funded or already spent: no UTXO available.'
    end
  end
  
  
  def create_puzzle_z
    
    @script = Script.find(params[:id])
    if @script_funded
      @script.first_unspent_tx
    else
      redirect_to @script, alert: 'Contract not funded or already spent: no UTXO available.'
    end
    
    if @script.puzzles.blank?
      @puzzle = Puzzle.create(:script_id => @script.id)
    else
      @puzzle = @script.puzzles.last
    end
     
    @tumbler_key = @script.tumbler_key # wif format string
    @previous_index = @script.index.to_i  # 
    @previous_id = @script.tx_hash

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
      # encrypt Tumbler's signature for Bob with symetric encryption key stored in @script.contract
      cipher = OpenSSL::Cipher::AES.new(128, :CBC)
      cipher.encrypt
      if @script.contract.blank?
        key = cipher.random_key  # generate random AES encryption key
        key_hex = key.to_hex
        puts key_hex
      
        iv = cipher.random_iv # generate random AES initialization vector
        iv_hex = iv.to_hex
      
        contract = key_hex + iv_hex  # epsilon, 128-bit key + 128-bit iv, total 256 bits
        # TODO Encrypt epsilon before storing in database
        @script.update(contract: contract) # store key + iv in @script contract attribute
      else
        contract = @script.contract
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
      
      # generate puzzle y by encrypting encryption key (@script.contract) with Tumbler RSA public key
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
      
      if @script.puzzles.blank?
        @puzzle = Puzzle.create(:script_id => @script.id, :y => puzzle, :encrypted_signature => @tumbler_encrypted_signature)
      else
        @puzzle = @script.puzzles.last
      end
  end

  def sign_tx
    
    require 'btcruby/extensions'
    
    @notice = "Tumblebit payout transaction was successfully signed."
    @script = Script.find(params[:id])
    @public_keys = @script.public_keys
    
    @script.confirmations = params[:script][:confirmations]
    @script.priv_key = params[:script][:priv_key]
    @script.oracle_1_priv_key = params[:script][:oracle_1_priv_key]
    @script.oracle_2_priv_key = params[:script][:oracle_2_priv_key]
    
    @script.alice_priv_key_1 = params[:script][:alice_priv_key_1]
    @script.alice_priv_key_2 = params[:script][:alice_priv_key_2]
    @script.bob_priv_key_1 = params[:script][:bob_priv_key_1]
    @script.bob_priv_key_2 = params[:script][:bob_priv_key_2]
    @script.secret = params[:script][:secret]
    @script.refund_address = params[:script][:refund_address]
    
    # ignore secret_ki parameters except secret_k1 for the demo, they are hardcoded to simplify the demo
    @script.secret_k1 = params[:script][:secret_k1] 
    @script.secret_k2 = params[:script][:secret_k2]
    @script.secret_k3 = params[:script][:secret_k3]
    @script.secret_k4 = params[:script][:secret_k4]
    @script.secret_k5 = params[:script][:secret_k5]
    @script.secret_k6 = params[:script][:secret_k6]
    @script.secret_k7 = params[:script][:secret_k7]
    @script.secret_k8 = params[:script][:secret_k8]
    @script.secret_k9 = params[:script][:secret_k9]
    @script.secret_k10 = params[:script][:secret_k10]
    @script.secret_k11 = params[:script][:secret_k11]
    @script.secret_k12 = params[:script][:secret_k12]
    @script.secret_k13 = params[:script][:secret_k13]
    @script.secret_k14 = params[:script][:secret_k14]
    @script.secret_k15 = params[:script][:secret_k15]
    
    @script.index = params[:script][:index]
    @script.tx_hash = params[:script][:tx_hash]
    @script.amount = params[:script][:amount]
    fee = 0.00015 # approx. 10 cts when 1 BTC = 700 EUR
    @previous_index = @script.index.to_i
    @previous_id = @script.tx_hash
    # @refund_address = BTC::Address.parse("16zQaNAg77jco2EDVSsU4bEAq5DgfZPZP4") # my electrum wallet
    
    begin  
      @refund_address = BTC::Address.parse(@script.refund_address)
    rescue Exception => era
      redirect_to @script, alert: "Invalid refund destination address."
      return
    end
    @script.update(refund_address: params[:script][:refund_address])

    @value = (@script.amount.to_f - fee) * BTC::COIN # @value is expressed in satoshis
    @funding_script = @script.funding_script
    
    case @script.category
        
      when "tumblebit_puzzle"
        
        @script.alice_pub_key_1 = PublicKey.where(:script_id => @script.id, :name => "Alice").last.compressed
        @script.oracle_1_pub_key = PublicKey.where(:script_id => @script.id, :name => "Tumbler").last.compressed
                                      
        unless @script.expired?
          puts "require Tumbler key, knowing puzzle solution"
          tx = BTC::Transaction.new

          tx.add_input(BTC::TransactionInput.new( previous_id: @previous_id,
                                                  previous_index: @previous_index,
                                                  sequence: 0))
          tx.add_output(BTC::TransactionOutput.new(value: @value, script: @refund_address.script))
          hashtype = BTC::SIGHASH_ALL
          sighash = tx.signature_hash(input_index: 0,
                                      output_script: @funding_script,
                                      hash_type: hashtype)
          tx.inputs[0].signature_script = BTC::Script.new
          
          begin  
            @tumbler_key = BTC::Key.new(wif:@script.oracle_1_priv_key)
          rescue Exception => et
            redirect_to @script, alert: "Invalid private key for Tumbler."
            return
          end
          if et.blank?
            puts "Tumbler signature appended"
            tx.inputs[0].signature_script << (@tumbler_key.ecdsa_signature(sighash) + BTC::WireFormat.encode_uint8(hashtype))
          end
          
          secret_k = Array[@script.secret_k1,@script.secret_k2,@script.secret_k3,@script.secret_k4,@script.secret_k5,@script.secret_k6,
            @script.secret_k7,@script.secret_k8,@script.secret_k9,@script.secret_k10,@script.secret_k11,@script.secret_k12,
            @script.secret_k13,@script.secret_k14,@script.secret_k15]
          k = Array.new
          string = ""
          for i in 0..14
            k[i] = secret_k[i].ripemd160
          end
          for i in 0..14
            string += k[i].ripemd160.to_hex
            tx.inputs[0].signature_script.append_pushdata(k[14-i])
          end
          if string != @script.contract
            redirect_to @script, alert: "Invalid puzzle value(s)."
            return
          end

          tx.inputs[0].signature_script << BTC::Script::OP_TRUE # force script execution into checking puzzle solution and Tumbler's signature
          
        else
          puts "after expiry, require only Alice key, ignoring puzzle solution."
          tx = BTC::Transaction.new
          tx.lock_time = @script.expiry_date.to_i + 1
          tx.add_input(BTC::TransactionInput.new( previous_id: @previous_id,
                                                  previous_index: @previous_index,
                                                  sequence: 0))
          tx.add_output(BTC::TransactionOutput.new(value: @value, script: @refund_address.script))
          hashtype = BTC::SIGHASH_ALL
          sighash = tx.signature_hash(input_index: 0,
                                      output_script: @funding_script,
                                      hash_type: hashtype)
          tx.inputs[0].signature_script = BTC::Script.new
          begin  
            @alice_key = BTC::Key.new(wif:@script.alice_priv_key_1)
          rescue Exception => ea
            redirect_to @script, alert: "Invalid private key for Alice."
            return
          end
          if ea.blank?
            puts "Alice signature appended"
            tx.inputs[0].signature_script << (@alice_key.ecdsa_signature(sighash) + BTC::WireFormat.encode_uint8(hashtype))
          end
          tx.inputs[0].signature_script << BTC::Script::OP_FALSE # force script execution into checking Alice's signature, ignoring puzzle solution
        end
        
        tx.inputs[0].signature_script << @funding_script.data
        
        
    when "tumblebit_escrow_contract"
      
      if @script.expired?
        puts "We are after expiry: require Tumbler key only"
        begin  
          @tumbler_key = BTC::Key.new(wif:@script.oracle_1_priv_key)
        rescue Exception => e
          redirect_to @script, alert: "Invalid Tumbler private key."
          return
        end

        tx = BTC::Transaction.new
        tx.lock_time = @script.expiry_date.to_i + 1 # time after expiry and before present (in the past)
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
        begin  
          @tumbler_key = BTC::Key.new(wif:@script.oracle_1_priv_key)
        rescue Exception => e
          redirect_to @script, alert: "Invalid Tumbler private key."
          return
        end

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
        if e.blank?
          data = @tumbler_key.ecdsa_signature(sighash)
          @tumbler_signature = BTC::Data.hex_from_data(data)
          # encrypt Tumbler's signature for Bob with symetric encryption key stored in @script.contract
          cipher = OpenSSL::Cipher::AES.new(128, :CBC)
          cipher.encrypt
          if @script.contract.blank?
            key = cipher.random_key  # generate random AES encryption key
            key_hex = key.to_hex
            puts key_hex
          
            iv = cipher.random_iv # generate random AES initialization vector
            iv_hex = iv.to_hex
          
            contract = key_hex + iv_hex  # epsilon, 128-bit key + 128-bit iv, total 256 bits
            # TODO Encrypt epsilon before storing in database
            @script.update(contract: contract) # store key + iv in @script contract attribute
          else
            contract = @script.contract
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
          
          # generate puzzle y by encrypting encryption key (@script.contract) with Tumbler RSA public key
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
          
          if @script.puzzles.blank?
            @puzzle = Puzzle.create(:script_id => @script.id, :y => puzzle, :encrypted_signature => @tumbler_encrypted_signature)
          else
            @puzzle = @script.puzzles.last
          end
        end
        
        @redeem_script = @funding_script.data.to_hex
      end
    end # of case statement
    @script.signed_tx = tx.to_s
    
    s = @notice
    if e
      s += e.message
    end
    unless s == "Tumblebit payout transaction was successfully signed."
      redirect_to @script, alert: s
    else
      flash[:notice] = s
    end
  end
  
  
  def broadcast
    @script = Script.find(params[:id])
    @script.signed_tx = params[:script][:signed_tx]

    # $PUSH_TX_URL = "https://api.blockcypher.com/v1/btc/main/txs/push"
    uri = URI.parse($PUSH_TX_URL)  # param is "tx"

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new(uri.path, {'Content-Type' =>'application/json'})
    data = {"tx": @script.signed_tx}
    request.body = data.to_json

    response = http.request(request)  # broadcast transaction using $PUSH_TX_URL
    
    post_response = JSON.parse(response.body)
    if post_response["error"]
      puts "Tx broadcast failed: #{post_response["error"]}"
      render 'show_failed_broadcast_tx', alert: "Tx broadcast failed. #{post_response["error"]}. Alternatively: copy the signed transaction below then paste it to https://coinb.in/#broadcast or try the Bitcoin Core sendrawtransaction command."
    else
      puts "Tx was broadcast successfully with Tx ID: #{post_response['tx']['hash']}"
      redirect_to @script, notice: "Tx was broadcast successfully with Tx ID: #{post_response['tx']['hash']}"
    end
  end
  
  
  def puzzle_list
    @scripts = Script.where(:category => 5).page(params[:page])
  end


  private
 
     def script_params
       params.require(:script).permit(:signed_tx, :refund_address, :alice_pub_key_1, :alice_pub_key_2, :bob_pub_key_1, :bob_pub_key_2,:oracle_1_pub_key,:oracle_2_pub_key, :contract, :title, :text, :expiry_date, :category, :user_id, public_keys_attributes: [:name, :compressed, :script_id])
     end

end