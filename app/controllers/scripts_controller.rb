class ScriptsController < ApplicationController


  def index
    @scripts = Script.all
  end
  
  def new
    @script = Script.new
  end
  
  def create
      @script = Script.new(script_params)

      if @script.save
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
      when "time_locked_address"
        if @script.public_keys.last
          @script.oracle_1_pub_key = @script.public_keys.last.compressed
        else
          @script.oracle_1_pub_key = ""
        end
        render :template => 'scripts/edit_tla'
      when "time_locked_2fa"
        if @script.public_keys.count < 2
          @script.public_keys.each do |public_key|
            public_key.destroy
          end
          @script.oracle_1_pub_key = ""
          @script.oracle_2_pub_key = ""
        else
          @script.oracle_1_pub_key = @script.public_keys.first.compressed
          @script.oracle_2_pub_key = @script.public_keys.last.compressed
        end
        render :template => 'scripts/edit_tl_2fa'
      when "contract_oracle"
        if @script.public_keys.count < 2
          @script.public_keys.each do |public_key|
            public_key.destroy
          end
          @script.oracle_1_pub_key = ""
          @script.oracle_2_pub_key = ""
        else
          @script.oracle_1_pub_key = @script.public_keys.first.compressed
          @script.oracle_2_pub_key = @script.public_keys.last.compressed
        end
        render :template => 'scripts/edit_contract_oracle'
      when "hashed_timelock_contract"
        if @script.public_keys.count < 4
          @script.public_keys.each do |public_key|
            public_key.destroy
          end
          @script.alice_pub_key_1 = ""
          @script.alice_pub_key_2 = ""
          @script.bob_pub_key_1 = ""
          @script.bob_pub_key_2 = ""
        else
          @script.alice_pub_key_1 = PublicKey.where(:script_id => @script.id, :name => "Alice 1").last.compressed
          @script.alice_pub_key_2 = PublicKey.where(:script_id => @script.id, :name => "Alice 2").last.compressed
          @script.bob_pub_key_1 = PublicKey.where(:script_id => @script.id, :name => "Bob 1").last.compressed
          @script.bob_pub_key_2 = PublicKey.where(:script_id => @script.id, :name => "Bob 2").last.compressed
          
        end
        render :template => 'scripts/edit_htlc'
      else
        render :template => 'scripts/edit'
    end
  end

  def update
    @script = Script.find(params[:id])
    @script.update_attributes(script_params)
    case @script.category
        when "time_locked_address"
          if @script.oracle_1_pub_key
            @public_key = PublicKey.new(:script_id => @script.id, :compressed => @script.oracle_1_pub_key, :name => "User")
            @public_key.save
          end
          @public_keys = @script.public_keys
          render 'show_tla'
        when "time_locked_2fa"
          if @script.oracle_1_pub_key
            @public_key = PublicKey.new(:script_id => @script.id, :compressed => @script.oracle_1_pub_key, :name => "Service")
            @public_key.save
          end
          if @script.oracle_2_pub_key
            @public_key = PublicKey.new(:script_id => @script.id, :compressed => @script.oracle_2_pub_key, :name => "User")
            @public_key.save
          end
          @public_keys = @script.public_keys
          render 'show_tl_2fa'
        when "contract_oracle"
          if @script.oracle_1_pub_key
            @public_key = PublicKey.new(:script_id => @script.id, :compressed => @script.oracle_1_pub_key, :name => "User")
            @public_key.save
          end
          if @script.oracle_2_pub_key
            @public_key = PublicKey.new(:script_id => @script.id, :compressed => @script.oracle_2_pub_key, :name => "Service")
            @public_key.save
          end
          @public_keys = @script.public_keys
          render 'show_contract_oracle'
        when "hashed_timelock_contract"
          
          
          
          if @script.alice_pub_key_1
            @public_key = PublicKey.new(:script_id => @script.id, :compressed => @script.alice_pub_key_1, :name => "Alice 1")
            @public_key.save
          end
          if @script.alice_pub_key_2
            @public_key = PublicKey.new(:script_id => @script.id, :compressed => @script.alice_pub_key_2, :name => "Alice 2")
            @public_key.save
          end
          if @script.bob_pub_key_1
            @public_key = PublicKey.new(:script_id => @script.id, :compressed => @script.bob_pub_key_1, :name => "Bob 1")
            @public_key.save
          end
          if @script.bob_pub_key_2
            @public_key = PublicKey.new(:script_id => @script.id, :compressed => @script.bob_pub_key_2, :name => "Bob 2")
            @public_key.save
          end
          @script.alice_pub_key_1 = PublicKey.where(:script_id => @script.id, :name => "Alice 1").last
          @script.alice_pub_key_2 = PublicKey.where(:script_id => @script.id, :name => "Alice 2").last
          @script.bob_pub_key_1 = PublicKey.where(:script_id => @script.id, :name => "Bob 1").last
          @script.bob_pub_key_2 = PublicKey.where(:script_id => @script.id, :name => "Bob 2").last
          @public_keys = @script.public_keys
          render 'show_htlc'
        else
          @public_keys = @script.public_keys
          render 'show'
    end

  end
  
  

  def show
    @script = Script.find(params[:id])
    @public_keys = @script.public_keys
    case @script.category
      when "time_locked_address"
        render 'show_tla'
      when "time_locked_2fa"
        render 'show_tl_2fa'
      when "contract_oracle"
        render 'show_contract_oracle'
      when "hashed_timelock_contract"
        @script.alice_pub_key_1 = PublicKey.where(:script_id => @script.id, :name => "Alice 1").last
        @script.alice_pub_key_2 = PublicKey.where(:script_id => @script.id, :name => "Alice 2").last
        @script.bob_pub_key_1 = PublicKey.where(:script_id => @script.id, :name => "Bob 1").last
        @script.bob_pub_key_2 = PublicKey.where(:script_id => @script.id, :name => "Bob 2").last
        render 'show_htlc'
      else
        render 'show'
    end
    
  end
  
  
  def destroy
    @script = Script.find_by_id(params[:id])
    @script.public_keys.each do |public_key|
      public_key.destroy
    end
    @script.destroy
      
    redirect_to scripts_path, notice: 'Script was successfully deleted.'
  end
  
  def create_spending_tx
    @script = Script.find(params[:id])
    
    case @script.category
      when "hashed_timelock_contract"
        @script.alice_pub_key_1 = PublicKey.where(:script_id => @script.id, :name => "Alice 1").last.compressed
        @script.alice_pub_key_2 = PublicKey.where(:script_id => @script.id, :name => "Alice 2").last.compressed
        @script.bob_pub_key_1 = PublicKey.where(:script_id => @script.id, :name => "Bob 1").last.compressed
        @script.bob_pub_key_2 = PublicKey.where(:script_id => @script.id, :name => "Bob 2").last.compressed
      else
        @public_keys = @script.public_keys
    end
    
    if @script.funded?
      @script.first_unspent_tx
    else
      redirect_to @script, alert: 'Script not funded: no UTXO available.'
    end
  end

  def sign_tx
    
    require 'btcruby/extensions'
    
    @notice = "Script spending tx was successfully signed."
    @script = Script.find(params[:id])
    @public_keys = @script.public_keys
    
    @script.priv_key = params[:script][:priv_key]
    @script.oracle_1_priv_key = params[:script][:oracle_1_priv_key]
    
    @script.alice_priv_key_1 = params[:script][:alice_priv_key_1]
    @script.alice_priv_key_2 = params[:script][:alice_priv_key_2]
    @script.bob_priv_key_1 = params[:script][:bob_priv_key_1]
    @script.bob_priv_key_2 = params[:script][:bob_priv_key_2]
    
    @script.index = params[:script][:index]
    @script.tx_hash = params[:script][:tx_hash]
    @script.amount = params[:script][:amount]
    fee = 0.0001  # approx. 5 cts when 1 BTC = 500 EUR
    @previous_index = @script.index.to_i
    @previous_id = @script.tx_hash
    @refund_address = BTC::Address.parse("16zQaNAg77jco2EDVSsU4bEAq5DgfZPZP4") # my electrum wallet
    @value = (@script.amount.to_f - fee) * BTC::COIN # @value is expressed in satoshis
    @funding_script = @script.funding_script
    
    case @script.category
      
      when "time_locked_address"
        
        if @script.expired?
          puts "We are after expiry: require user key only"
          # trying to spend 54 minutes after expiry returns "non-final"
          begin  
            @user_key = BTC::Key.new(wif:@script.priv_key)
          rescue Exception => e  
            puts e.message
            @notice = "Bad private key."
          end
          # Private keys associated with compressed public keys are 52 characters and start with a capital L or K on mainnet (c on testnet).
          if ((@script.priv_key.size > 52) or (@notice == "Bad private key."))
            @notice = "Private key is too long."
            redirect_to root_url, alert: @notice
            return
          end
          tx = BTC::Transaction.new
          # tx.lock_time = 1473269401
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
          tx.inputs[0].signature_script << (@user_key.ecdsa_signature(sighash) + BTC::WireFormat.encode_uint8(hashtype))
          tx.inputs[0].signature_script << @funding_script.data
        else
          @notice = "before expiry, no way to spend script, the network will return: Locktime requirement not satisfied"
          # trying to spend before expiry with user key only and a locktime in the past should return "Locktime requirement not satisfied".
          # this error message means that the network rejects the tx based on the expiry date set int the script even if the tx locktime is in the past.
          begin  
            @user_key = BTC::Key.new(wif:@script.priv_key)
          rescue Exception => e  
            puts e.message 
            @notice = "Bad private key."
          end
          # Private keys associated with compressed public keys are 52 characters and start with a capital L or K on mainnet (c on testnet).
          if ((@script.priv_key.size > 52) or (@notice == "Bad private key."))
            @notice = "Private key is too long."
            redirect_to root_url, alert: @notice
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
          tx.inputs[0].signature_script << (@user_key.ecdsa_signature(sighash) + BTC::WireFormat.encode_uint8(hashtype))
          tx.inputs[0].signature_script << @funding_script.data
        end
      
      when "time_locked_2fa"
        
        if @script.expired?
          puts "We are after expiry: 2FA expired, require user key only"
          # spending with both user key and service key is still possible.
          # trying to spend 31 minutes after expiry returns "non-final"
          # trying to spend 56 minutes after expiry works!"
          begin  
            @user_key = BTC::Key.new(wif:@script.priv_key)
          rescue Exception => e 
            @notice = "Bad private key."
          end
          # Private keys associated with compressed public keys are 52 characters and start with a capital L or K on mainnet (c on testnet).
          if ((@script.priv_key.size > 52) or (@notice == "Bad private key."))
            @notice = "Private key is too long."
            redirect_to root_url, alert: @notice
            return
          end
          tx = BTC::Transaction.new
          # tx.lock_time = 1473269401
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
          tx.inputs[0].signature_script << (@user_key.ecdsa_signature(sighash) + BTC::WireFormat.encode_uint8(hashtype))
          tx.inputs[0].signature_script << BTC::Script::OP_FALSE # force script execution into checking that expiry was before locktime, then locktime is checked to be in the past as well
          tx.inputs[0].signature_script << @funding_script.data
        else
          puts "2FA, before expiry, require both user key and service key"
          # trying to spend before expiry with user key only and a locktime in the past should return "Locktime requirement not satisfied".
          # this error message means that the network rejects the tx based on the expiry date set int the script even if the tx locktime is in the past.
          begin  
            @user_key = BTC::Key.new(wif:@script.priv_key)
          rescue Exception => e  
            @notice = "Bad private key."
          end
          begin  
            @escrow_key=BTC::Key.new(wif:@script.oracle_1_priv_key)
          rescue Exception => e  
            @notice = "Bad private key."
          end
          # Private keys associated with compressed public keys are 52 characters and start with a capital L or K on mainnet (c on testnet).
          if ((@script.priv_key.size > 52) or (@notice == "Bad private key."))
            @notice = "User private key is too long."
            redirect_to root_url, alert: @notice
            return
          end
          # Private keys associated with compressed public keys are 52 characters and start with a capital L or K on mainnet (c on testnet).
          if ((@script.oracle_1_priv_key.size > 52) or (@notice == "Bad private key."))
            @notice = "Escrow private key is too long."
            redirect_to root_url, alert: @notice
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
          tx.inputs[0].signature_script << (@user_key.ecdsa_signature(sighash) + BTC::WireFormat.encode_uint8(hashtype))
          tx.inputs[0].signature_script << (@escrow_key.ecdsa_signature(sighash) + BTC::WireFormat.encode_uint8(hashtype))
          tx.inputs[0].signature_script << BTC::Script::OP_TRUE # force script execution into checking 2 signatures, ignoring expiry
          tx.inputs[0].signature_script << @funding_script.data
        end
        
      when "contract_oracle" # <hash> OP_DROP 2 <beneficiary pubkey> <oracle pubkey> CHECKMULTISIG
                            # <hash>: SHA256 of a json file like { "param_1":"value_1", "param_2":"value_2" }
                            # param_1 and 2 are described in the contract, value_1 and 2 come from external data sources
        puts "require both user key and oracle key"
        begin  
          @user_key = BTC::Key.new(wif:@script.priv_key)
        rescue Exception => e 
          @notice = "Bad private key."
        end
        begin  
          @escrow_key=BTC::Key.new(wif:@script.oracle_1_priv_key)
        rescue Exception => e
          @notice = "Bad private key."
        end
         # Private keys associated with compressed public keys are 52 characters and start with a capital L or K on mainnet (c on testnet).
          if ((@script.priv_key.size != 52) or (@notice == "Bad private key."))
            @notice = "User private key length is not 52 chars."
            redirect_to root_url, alert: @notice
            return
          end
          # Private keys associated with compressed public keys are 52 characters and start with a capital L or K on mainnet (c on testnet).
          if ((@script.oracle_1_priv_key.size != 52) or (@notice == "Bad private key."))
            @notice = "Escrow private key length is not 52 chars."
            redirect_to root_url, alert: @notice
            return
          end
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
        tx.inputs[0].signature_script << BTC::Script::OP_FALSE
        tx.inputs[0].signature_script << (@user_key.ecdsa_signature(sighash) + BTC::WireFormat.encode_uint8(hashtype))
        tx.inputs[0].signature_script << (@escrow_key.ecdsa_signature(sighash) + BTC::WireFormat.encode_uint8(hashtype))

        tx.inputs[0].signature_script << @funding_script.data
      
      when "hashed_timelock_contract" #   IF
                                      #   HASH160 <hash160(S)> EQUALVERIFY
                                      #   FALSE 2 <AlicePubkey1> <BobPubkey1>
                                      #   ELSE
                                      #   FALSE 2 <AlicePubkey2> <BobPubkey2>
                                      #   ENDIF
                                      #   2 CHECKMULTISIG
        # puts "require S and both Alice key 1 and Bob key 1"
        puts "require only Alice key 2 and Bob key 2"
        begin  
          @alice_key_1 = BTC::Key.new(wif:@script.alice_priv_key_1)
        rescue Exception => e 
          @notice = "Bad private key."
        end
        begin  
          @bob_key_1=BTC::Key.new(wif:@script.bob_priv_key_1)
        rescue Exception => e
          @notice = "Bad private key."
        end
         # Private keys associated with compressed public keys are 52 characters and start with a capital L or K on mainnet (c on testnet).
          if ((@script.alice_priv_key_1.size != 52) or (@notice == "Bad private key."))
            @notice = "Alice's private key length is not 52 chars."
            redirect_to root_url, alert: @notice
            return
          end
          # Private keys associated with compressed public keys are 52 characters and start with a capital L or K on mainnet (c on testnet).
          if ((@script.bob_priv_key_1.size != 52) or (@notice == "Bad private key."))
            @notice = "Bob's private key length is not 52 chars."
            redirect_to root_url, alert: @notice
            return
          end
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
        # tx.inputs[0].signature_script.append_pushdata(@script.contract)
        tx.inputs[0].signature_script << (@alice_key_1.ecdsa_signature(sighash) + BTC::WireFormat.encode_uint8(hashtype))
        tx.inputs[0].signature_script << (@bob_key_1.ecdsa_signature(sighash) + BTC::WireFormat.encode_uint8(hashtype))
        tx.inputs[0].signature_script << BTC::Script::OP_FALSE # force script execution into checking 2 signatures, ignoring S
        tx.inputs[0].signature_script << @funding_script.data

    end
    @script.signed_tx = tx.to_s
    # @script.update_attributes(script_params)
    puts @notice
    puts tx.to_s
    unless @notice == "Script spending tx was successfully signed."
      redirect_to @script, alert: @notice
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
      redirect_to @script, alert: "Tx broadcast failed. "+"#{post_response["error"]}"
    else
      puts "Tx was broadcast successfully with Tx ID: #{post_response['tx']['hash']}"
      redirect_to @script, notice: "Tx was broadcast successfully with Tx ID: #{post_response['tx']['hash']}"
    end
  end


  private
 
     def script_params
       params.require(:script).permit(:alice_pub_key_1, :alice_pub_key_2, :bob_pub_key_1, :bob_pub_key_2,:oracle_1_pub_key,:oracle_2_pub_key, :contract, :title, :text, :expiry_date, :category, public_keys_attributes: [:name, :compressed, :script_id])
     end

end