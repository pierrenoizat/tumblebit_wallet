class Script < ActiveRecord::Base
  
  enum category: [:time_locked_2fa]
  
  has_many :public_keys
  
  require 'btcruby/extensions'
  
  def hash_address
    unless self.public_keys.blank?
    if self.public_keys.count != 2 and self.category == :time_locked_2fa
      return "Time locked 2FA Script to Hash Address require 2 keys."
    else
      BTC::Network.default= BTC::Network.mainnet
      @funding_script = BTC::Script.new
      # @escrow_key=BTC::Key.new(wif:"KwtnGxYSfyCM888BDa94SPDxLE934F3cDBfgJy3h4gGUSrGFzAVw")
      # @user_key=BTC::Key.new(wif:"L1SPHyPeb63ZXVEQ1YHrbaTjiTEZe9oTTxtHLEcox3SsbsBue1Z4")
      @escrow_key=BTC::Key.new(public_key:BTC.from_hex(self.public_keys.first.compressed))
      @user_key=BTC::Key.new(public_key:BTC.from_hex(self.public_keys.last.compressed))
      # @expire_at = Time.at(1472240000) # 2016-08-26 21:33:20 +0200
      # Time.at(1472239980)
      # @expire_at = Time.at(1472239980)
      # @expire_at = self.expiry_date
      @expire_at = Time.at((self.expiry_date.to_time.to_i + 20))
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
      funded_address=BTC::ScriptHashAddress.new(redeem_script:@funding_script, network:BTC::Network.default)
      # <BTC::ScriptHashAddress:3F8fc3FboEKb5rnmYUNQTuihZBkyPy4aNM>
    end
  else
    return "Script must have key(s)."
  end
  end
  
  def expired_spending_tx
    BTC::Network.default= BTC::Network.mainnet
    @funding_script = BTC::Script.new
    # @escrow_key=BTC::Key.new(wif:"KwtnGxYSfyCM888BDa94SPDxLE934F3cDBfgJy3h4gGUSrGFzAVw")
    @user_key=BTC::Key.new(wif:"L1SPHyPeb63ZXVEQ1YHrbaTjiTEZe9oTTxtHLEcox3SsbsBue1Z4")
    @escrow_key=BTC::Key.new(public_key:BTC.from_hex(self.public_keys.first.compressed))
    @expire_at = Time.at((self.expiry_date.to_time.to_i + 20))
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
    @previous_index = 0
    @previous_id = "1904c6940e897554877b669f4e4f2581eba39d78e170378c6eee622a0fcb4963"
    @refund_address = BTC::Address.parse("16zQaNAg77jco2EDVSsU4bEAq5DgfZPZP4") # my electrum wallet
    @value = 0.0008 * BTC::COIN # @value is expressed in satoshis
    tx = BTC::Transaction.new
    tx.lock_time = 1472240000 + 1 # time after expiry and before present (in the past)
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
    tx.to_s
  end
  
end
