class Script < ActiveRecord::Base
  
  enum category: [:time_locked_address, :time_locked_2fa, :contract_oracle]
  
  attr_accessor :tx_hash, :index, :amount, :confirmations, :priv_key, :oracle_1_priv_key, :oracle_2_priv_key
  
  # self.contract is a string of the form "{param_1:value_1,param_2:value_2}", e.g "{time_limit:1474299166,rate_limit:545.00}" for a futures contract on the EUR/BTC exchange rate
  
  has_many :public_keys
  
  after_initialize :init
  
  require 'btcruby/extensions'
  require 'mechanize'
  require 'digest'
  
  def description
    case self.category
      when "time_locked_address"
        "<expiry time> CHECKLOCKTIMEVERIFY DROP <public key> CHECKSIG"
        
      when "time_locked_2fa"
        "IF <service public key> CHECKSIGVERIFY
        ELSE <expiry time> CHECKLOCKTIMEVERIFY DROP 
        ENDIF
 <user public key> CHECKSIG"
        
      when "contract_oracle"
        "<contract_hash> DROP 2 <beneficiary pubkey> <oracle pubkey> 2 CHECKMULTISIG"
    end
  end
  
  
  def init
    self.expiry_date  ||= Time.now.utc  #will set the default value only if it's nil
  end
  
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
        # <hash>: SHA256 of a string like "{param_1:value_1,param_2:value_2}"
        # param_1 and 2 are described in the contract, value_1 and 2 come from external data sources
        # value_1 and 2 must match the values set in the contract for the hash to match contract_hash
        @contract_hash = Digest::SHA256.digest self.contract
        @escrow_key=BTC::Key.new(public_key:BTC.from_hex(self.public_keys.first.compressed))
        @user_key=BTC::Key.new(public_key:BTC.from_hex(self.public_keys.last.compressed))
        @funding_script.append_pushdata(@contract_hash)
        @funding_script<<BTC::Script::OP_DROP
        @funding_script<<BTC::Script::OP_2
        @funding_script<<@user_key.compressed_public_key
        @funding_script<<@escrow_key.compressed_public_key
        @funding_script<<BTC::Script::OP_2
        @funding_script<<BTC::Script::OP_CHECKMULTISIG
    end
    return @funding_script
  end
  
  
  def hash_address
    
    unless self.public_keys.blank?
      case self.category
        when "time_locked_address"
            funded_address=BTC::ScriptHashAddress.new(redeem_script:self.funding_script, network:BTC::Network.default)
            # <BTC::ScriptHashAddress:3F8fc3FboEKb5rnmYUNQTuihZBkyPy4aNM>
            # script uses the last public key saved with the script
        when "time_locked_2fa", "contract_oracle"
          if self.public_keys.count != 2
            return nil # Script to Hash Address requires 2 keys.
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
    if (self.expiry_date and (["time_locked_address", "time_locked_2fa"].include? self.category))
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
