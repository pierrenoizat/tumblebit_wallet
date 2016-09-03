class Script < ActiveRecord::Base
  
  has_many :public_keys
  
  def hash_address
    
    require 'btcruby/extensions'
    BTC::Network.default= BTC::Network.mainnet
    @funding_script = BTC::Script.new
    @escrow_key=BTC::Key.new(wif:"KwtnGxYSfyCM888BDa94SPDxLE934F3cDBfgJy3h4gGUSrGFzAVw")
    @user_key=BTC::Key.new(wif:"L1SPHyPeb63ZXVEQ1YHrbaTjiTEZe9oTTxtHLEcox3SsbsBue1Z4")
    @expire_at = Time.at(1472240000) # 2016-08-26 21:33:20 +0200
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
  
end
