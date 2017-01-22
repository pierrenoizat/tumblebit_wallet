class Script < ActiveRecord::Base
  
  validates_presence_of :title
  # validates :expiry_date, :timeliness => {:after => lambda { Date.current }, :type => :datetime }  uncomment to prevent user from creating expired address
  validates :expiry_date, :timeliness => {:type => :datetime }
  
  enum category: [:tumblebit_escrow_contract, :tumblebit_puzzle]
  attr_accessor :priv_key, :oracle_1_priv_key, :oracle_2_priv_key, :oracle_1_pub_key, :oracle_2_pub_key
  attr_accessor :alice_priv_key_1, :alice_priv_key_2, :bob_priv_key_1, :bob_priv_key_2
  attr_accessor :alice_pub_key_1, :alice_pub_key_2, :bob_pub_key_1, :bob_pub_key_2
  attr_accessor :tx_hash, :index, :amount, :confirmations, :signed_tx, :secret
  attr_accessor :secret_k1,:secret_k2,:secret_k3,:secret_k4,:secret_k5,:secret_k6,:secret_k7
  attr_accessor :secret_k8,:secret_k9,:secret_k10,:secret_k11,:secret_k12,:secret_k13,:secret_k14,:secret_k15
  
  # self.contract is a string of the form "{param_1:value_1,param_2:value_2}", e.g "{time_limit:1474299166,price_limit:545.00}" for a futures contract on the EUR/BTC exchange rate
  
  has_many :public_keys
  has_many :puzzles
  belongs_to :user
  belongs_to :client
  
  after_initialize :init
  
  require 'btcruby/extensions'
  require 'mechanize'
  require 'digest'
  
  self.per_page = 10
  
  def description
    case self.category
        
      when "tumblebit_puzzle"
        "       IF
        RIPEMD160 <h1> EQUALVERIFY
        ...
        RIPEMD160 <h15> EQUALVERIFY
        <tumbler pubkey> CHECKSIG
        ELSE
        <expiry time> CHECKLOCKTIMEVERIFY DROP
        <AlicePubkey> CHECKSIG
        ENDIF"
        
      when "tumblebit_escrow_contract"
        "        IF 
        2 <Tumbler> <Bob> 2 CHECKMULTISIG
        ELSE 
        <expiry time> CHECKLOCKTIMEVERIFY DROP
        <Tumbler> CHECKSIG
        ENDIF"
    end
  end
  
  
  def init
    self.expiry_date  ||= Time.now.utc  #will set the default value only if it's nil
    self.category ||= "tumblebit_escrow_contract"
  end
  
  def funding_script
    BTC::Network.default= BTC::Network.mainnet
    @funding_script = BTC::Script.new
    
    case self.category
        
      when "tumblebit_puzzle"
        @alice_pub_key = PublicKey.where(:script_id => self.id, :name => "Alice").last
        @tumbler_pub_key = PublicKey.where(:script_id => self.id, :name => "Tumbler").last
        @alice_key=BTC::Key.new(public_key:BTC.from_hex(@alice_pub_key.compressed))
        @tumbler_key=BTC::Key.new(public_key:BTC.from_hex(@tumbler_pub_key.compressed))
        
        @expire_at = Time.at(self.expiry_date.to_time.to_i)
        h = Array.new
        unless self.contract.blank?
          contract = self.contract
          puts "Contract title: #{self.title}"
          puts "Contract string: #{contract}"
          puts "Contract string size: #{contract.size}"
          h[1] = self.contract[0..39] # each RIPEMD digest is 40 hex char. long
          h[2] = self.contract[40..79]
          h[3] =  self.contract[80..119]
          h[4] =  self.contract[120..159]
          h[5] =  self.contract[160..199]
          h[6] =  self.contract[200..239]
          h[7] = self.contract[240..279]
          h[8] = self.contract[280..319]
          h[9] = self.contract[320..359]
          h[10] = self.contract[360..399]
          h[11] = self.contract[400..439]
          h[12] = self.contract[440..479]
          h[13] =  self.contract[480..519]
          h[14] = self.contract[520..559]
          h[15] = self.contract[560..599]
          @funding_script<<BTC::Script::OP_IF
          j=0
          for i in 1..15
            # self.update(contract: h[i])
            @funding_script<<BTC::Script::OP_RIPEMD160
            @funding_script.append_pushdata(BTC::Data.data_from_hex(h[i]))
            puts "#{h[i]}"
            @funding_script<<BTC::Script::OP_EQUALVERIFY
            j+=1
          end
          # self.update(contract: contract)
          puts "Compteur: #{j}"
          @funding_script<<@tumbler_key.compressed_public_key
          @funding_script<<BTC::Script::OP_CHECKSIG
        
          @funding_script<<BTC::Script::OP_ELSE
        
          @funding_script<<BTC::WireFormat.encode_int32le(@expire_at.to_i)
          @funding_script<<BTC::Script::OP_CHECKLOCKTIMEVERIFY
          @funding_script<<BTC::Script::OP_DROP
          @funding_script<<@alice_key.compressed_public_key
          @funding_script<<BTC::Script::OP_CHECKSIG
        
          @funding_script<<BTC::Script::OP_ENDIF
        else
          return nil
        end
        
        
    when "tumblebit_escrow_contract"
        self.bob_pub_key_1 = PublicKey.where(:script_id => self.id, :name => "Bob").last.compressed
        unless self.tumbler_key.blank?
        key = BTC::Key.new(wif: self.tumbler_key)
        self.oracle_1_pub_key = key.compressed_public_key.to_hex
        puts "Tumbler public key: #{self.oracle_1_pub_key}"
        # self.oracle_1_pub_key = PublicKey.where(:script_id => self.id, :name => "Tumbler").last.compressed
        @tumbler_key=BTC::Key.new(public_key:BTC.from_hex(self.oracle_1_pub_key))
        @user_key=BTC::Key.new(public_key:BTC.from_hex(self.bob_pub_key_1))
        @expire_at = Time.at(self.expiry_date.to_time.to_i)
        
        @funding_script<<BTC::Script::OP_IF
        @funding_script<<BTC::Script::OP_2
        @funding_script<<@tumbler_key.compressed_public_key
        @funding_script<<@user_key.compressed_public_key
        @funding_script<<BTC::Script::OP_2
        @funding_script<<BTC::Script::OP_CHECKMULTISIG
        @funding_script<<BTC::Script::OP_ELSE
        @funding_script<<BTC::WireFormat.encode_int32le(@expire_at.to_i)
        @funding_script<<BTC::Script::OP_CHECKLOCKTIMEVERIFY
        @funding_script<<BTC::Script::OP_DROP
        @funding_script<<@tumbler_key.compressed_public_key
        @funding_script<<BTC::Script::OP_CHECKSIG
        @funding_script<<BTC::Script::OP_ENDIF
      end
        
    end # of case statement
    return @funding_script
  end
  
  
  def hash_address
    # compute P2SH address for self.funding_script
    unless self.public_keys.count == 0
      case self.category
          
        when "tumblebit_puzzle"
          if PublicKey.where(:script_id => self.id, :name => "Alice").last
            self.alice_pub_key_1 = PublicKey.where(:script_id => self.id, :name => "Alice").last.compressed
          end
          if PublicKey.where(:script_id => self.id, :name => "Tumbler").last
            self.oracle_1_pub_key = PublicKey.where(:script_id => self.id, :name => "Tumbler").last.compressed
          end
          if (self.alice_pub_key_1.blank? or self.oracle_1_pub_key.blank? )
            return nil # Script to Hash Address requires 2 keys.
          else
            funded_address=BTC::ScriptHashAddress.new(redeem_script:self.funding_script, network:BTC::Network.default)
          end
          
        when "tumblebit_escrow_contract"
          if PublicKey.where(:script_id => self.id, :name => "Bob").last
            self.bob_pub_key_1 = PublicKey.where(:script_id => self.id, :name => "Bob").last.compressed
          end
          if self.tumbler_key
            key = BTC::Key.new(wif: self.tumbler_key)
            self.oracle_1_pub_key = key.compressed_public_key.to_hex
          end
          if (self.bob_pub_key_1.blank? or self.tumbler_key.blank? )
            return nil # Script to Hash Address requires 2 keys.
          else
            funded_address=BTC::ScriptHashAddress.new(redeem_script:self.funding_script, network:BTC::Network.default)
          end
        end # of case statement
  else
    return nil
  end
  end
  
  
  def funded?
    
    if !self.hash_address.blank?
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
      if  (result['data']['balance'] > 0)
        return true
      else
        string = $BLOCKCHAIN_ADDRESS_BALANCE_URL + self.hash_address.to_s + "?format=json" # check another source, just in case
        begin
          page = @agent.get string
        rescue Exception => e
          page = e.page
        end

        data = page.body
        result = JSON.parse(data)
        if  (result['final_balance'] > 0)
          return true
        else
          return false
        end
      end
    else
      return false
    end
  end
  
  
  def virgin?
    virgin = false
    if !self.hash_address.blank?
      string = $BLOCKR_ADDRESS_TXS_URL + self.hash_address.to_s
      @agent = Mechanize.new
      puts "#{self.hash_address}"
      begin
        page = @agent.get string
      rescue Exception => e
        page = e.page
      end

      data = page.body
      result = JSON.parse(data)

      virgin = (result['data']['nb_txs'] == 0)
      puts "Number of transactions= #{result['data']['nb_txs']}"
      string = $BLOCKR_ADDRESS_UNSPENT_URL + self.hash_address.to_s + + "?unconfirmed=1"
      @agent = Mechanize.new

      begin
        page = @agent.get string
      rescue Exception => e
        page = e.page
      end

      data = page.body
      result = JSON.parse(data)

      virgin = virgin and (result['data']['unspent'].count == 0)
      puts "Number of unconfirmed transactions= #{result['data']['unspent'].count}"
    else
      virgin = true
    end
    return virgin
  end
  
  def expired?
    if (self.expiry_date and (["tumblebit_puzzle", "tumblebit_escrow_contract"].include? self.category))
      return (Time.now.to_i > self.expiry_date.to_i)
    else
      return false
    end
  end
  
  def first_unspent_tx
    
    string = $BLOCKR_ADDRESS_UNSPENT_URL + self.hash_address.to_s + "?unconfirmed=1" # with_unconfirmed
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
