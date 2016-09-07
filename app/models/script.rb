class Script < ActiveRecord::Base
  
  enum category: [:time_locked_2fa]
  
  attr_accessor :tx_hash, :index, :amount, :confirmations, :priv_key, :service_priv_key
  
  has_many :public_keys
  
  require 'btcruby/extensions'
  require 'mechanize'
  
  def funding_script
    BTC::Network.default= BTC::Network.mainnet
    @funding_script = BTC::Script.new
    # @escrow_key=BTC::Key.new(wif:"KwtnGxYSfyCM888BDa94SPDxLE934F3cDBfgJy3h4gGUSrGFzAVw")
    # @user_key=BTC::Key.new(wif:"L1SPHyPeb63ZXVEQ1YHrbaTjiTEZe9oTTxtHLEcox3SsbsBue1Z4")
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
  end
  
  def hash_address
    unless self.public_keys.blank?
    if self.public_keys.count != 2 and self.category == :time_locked_2fa
      return "Time locked 2FA Script to Hash Address require 2 keys."
    else
      funded_address=BTC::ScriptHashAddress.new(redeem_script:self.funding_script, network:BTC::Network.default)
      # <BTC::ScriptHashAddress:3F8fc3FboEKb5rnmYUNQTuihZBkyPy4aNM>
    end
  else
    return "Script must have key(s)."
  end
  end
  
  
  def funded?
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
