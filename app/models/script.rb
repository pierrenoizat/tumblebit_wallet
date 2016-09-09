class Script < ActiveRecord::Base
  
  enum category: [:time_locked_address, :time_locked_2fa, :contract_oracle]
  
  attr_accessor :tx_hash, :index, :amount, :confirmations, :priv_key, :oracle_1_priv_key, :oracle_2_priv_key
  
  has_many :public_keys
  
  require 'btcruby/extensions'
  require 'mechanize'
  
  def funding_script
    BTC::Network.default= BTC::Network.mainnet
    @funding_script = BTC::Script.new
    
    case self.category
      when "time_locked_address" #  <expiry time> CHECKLOCKTIMEVERIFY DROP <pubkey> CHECKSIG
        
        # @escrow_key=BTC::Key.new(wif:"KwtnGxYSfyCM888BDa94SPDxLE934F3cDBfgJy3h4gGUSrGFzAVw")
        # @user_key=BTC::Key.new(wif:"L1SPHyPeb63ZXVEQ1YHrbaTjiTEZe9oTTxtHLEcox3SsbsBue1Z4")
        @user_key=BTC::Key.new(public_key:BTC.from_hex(self.public_keys.last.compressed))
        @expire_at = Time.at(self.expiry_date.to_time.to_i)
        @funding_script<<BTC::WireFormat.encode_int32le(@expire_at.to_i)
        @funding_script<<BTC::Script::OP_CHECKLOCKTIMEVERIFY
        @funding_script<<BTC::Script::OP_DROP
        @funding_script<<@user_key.compressed_public_key
        @funding_script<<BTC::Script::OP_CHECKSIG
        
      when "time_locked_2fa"
        
        @escrow_key=BTC::Key.new(public_key:BTC.from_hex(self.public_keys.first.compressed))
        @user_key=BTC::Key.new(public_key:BTC.from_hex(self.public_keys.last.compressed))
        @expire_at = Time.at(self.expiry_date.to_time.to_i)
        @funding_script<<BTC::Script::OP_IF
        @funding_script<<@escrow_key.compressed_public_key
        @funding_script<<BTC::Script::OP_CHECKSIGVERIFY
        @funding_script<<BTC::Script::OP_ELSE
        @funding_script<<BTC::WireFormat.encode_int32le(@expire_at.to_i)
        @funding_script<<BTC::Script::OP_CHECKLOCKTIMEVERIFY
        @funding_script<<BTC::Script::OP_DROP
        @funding_script<<BTC::Script::OP_ENDIF
        @funding_script<<@user_key.compressed_public_key
        @funding_script<<BTC::Script::OP_CHECKSIG
        # <BTC::Script "OP_IF 026edc650b929056b58e4247274a02e3f1665dd10fb1da2575ebae27447f24363e
        # OP_CHECKSIGVERIFY OP_ELSE [8099c057] OP_CHECKLOCKTIMEVERIFY OP_DROP OP_ENDIF
        # 0258f00dff2457bba1b536709a9f5e27488eeb24e59a1c9dccb4d2fd52568e4d40 OP_CHECKSIG" (80 bytes)>
        
      when "contract_oracle"   # <contract_hash> OP_DROP 2 <beneficiary pubkey> <oracle pubkey> CHECKMULTISIG
        # <hash>: SHA256 of a json file like { "param_1":"value_1", "param_2":"value_2" }
        # param_1 and 2 are described in the contract, value_1 and 2 come from external data sources
        # value_1 and 2 must match the values set in the contract for the hash to match contract_hash
        @escrow_key=BTC::Key.new(public_key:BTC.from_hex(self.public_keys.first.compressed))
        @user_key=BTC::Key.new(public_key:BTC.from_hex(self.public_keys.last.compressed))
        @funding_script<<BTC::Script::OP_PUSHDATA1 # will be followed by length of data to be pushed to the stack (length defined over 1 byte )
        @funding_script<<"\x21" # length over 1 byte: push 32 bytes (256 bits) on stack
        @funding_script<<@contract_hash
        @funding_script<<BTC::Script::OP_DROP
        @funding_script<<BTC::Script::OP_2
        @funding_script<<@user_key.compressed_public_key
        @funding_script<<@escrow_key.compressed_public_key
        @funding_script<<BTC::Script::OP_CHECKMULTISIG
    end
    return @funding_script
  end
  
  
  def signed_transaction
    @notice = "Script spending tx was successfully signed."
    @script = Script.find(params[:id])
    @public_keys = @script.public_keys
    @script.priv_key = params[:script][:priv_key]
    @script.oracle_1_priv_key = params[:script][:oracle_1_priv_key]
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
          @user_key = BTC::Key.new(wif:@script.priv_key)
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
          @user_key = BTC::Key.new(wif:@script.priv_key)
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
          @user_key = BTC::Key.new(wif:@script.priv_key)
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
          @user_key = BTC::Key.new(wif:@script.priv_key)
          @escrow_key=BTC::Key.new(wif:@script.oracle_1_priv_key)
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
      when "contract_oracle" # <contract_hash> OP_DROP 2 <beneficiary pubkey> <oracle pubkey> CHECKMULTISIG
        puts "require both user key and oracle key"
        @user_key = BTC::Key.new(wif:@script.priv_key)
        @escrow_key=BTC::Key.new(wif:@script.oracle_1_priv_key)
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
        tx.inputs[0].signature_script << @contract_hash  # ???
        tx.inputs[0].signature_script << (@user_key.ecdsa_signature(sighash) + BTC::WireFormat.encode_uint8(hashtype))
        tx.inputs[0].signature_script << (@escrow_key.ecdsa_signature(sighash) + BTC::WireFormat.encode_uint8(hashtype))
        tx.inputs[0].signature_script << @funding_script.data
      else
    end
    
    puts tx.to_s
    return tx
  end
  
  
  def hash_address
    
    unless self.public_keys.blank?
      case self.category
        when "time_locked_address"
            funded_address=BTC::ScriptHashAddress.new(redeem_script:self.funding_script, network:BTC::Network.default)
            # <BTC::ScriptHashAddress:3F8fc3FboEKb5rnmYUNQTuihZBkyPy4aNM>
            # script uses the last public key saved with the script
        when "time_locked_2fa"
          if self.public_keys.count != 2
            return nil # Time locked 2FA Script to Hash Address require 2 keys.
          else
            funded_address=BTC::ScriptHashAddress.new(redeem_script:self.funding_script, network:BTC::Network.default)
            # <BTC::ScriptHashAddress:3F8fc3FboEKb5rnmYUNQTuihZBkyPy4aNM>
          end
        end # of case statetement
  else
    return nil
  end
  end
  
  
  def funded?
    if self.hash_address
      string = $BLOCKR_ADDRESS_BALANCE_URL + self.hash_address.to_s + "?confirmations=0"
      @agent = Mechanize.new

      begin
        page = @agent.get string
      rescue Exception => e
        page = e.page
      end

      data = page.body
      result = JSON.parse(data)
      puts result
      puts "True? #{result['data']['balance']}"
      return (result['data']['balance'] > 0)
    else
      return false
    end
  end
  
  def expired?
    if self.expiry_date
      return (Time.now.to_i > self.expiry_date.to_i)
    else
      return false
    end
  end
  
  def first_unspent_tx
    string = $BLOCKR_ADDRESS_UNSPENT_URL + self.hash_address.to_s
    @agent = Mechanize.new

    begin
    page = @agent.get string
    rescue Exception => e
    page = e.page
    end

    data = page.body
    result = JSON.parse(data)
    puts result
    if !result['data']['unspent'].blank?
      self.tx_hash = result['data']['unspent'][0]['tx']
      self.index = result['data']['unspent'][0]['n']
      self.amount = result['data']['unspent'][0]['amount']
      self.confirmations = result['data']['unspent'][0]['confirmations']
      puts "Tx hash: #{self.tx_hash}"
      return true
    else
      puts "No utxo avalaible for #{self.hash_address}"
      return false
    end
  end
  
end
