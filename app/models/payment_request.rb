class PaymentRequest < ActiveRecord::Base
  
  include AASM

   aasm do # default column: aasm_state
     state :started, :initial => true
     state :step1, :step2,:step4, :step6,:step7,:step8,:step10
     state :completed

     event :request_created do
        transitions :from => :started, :to => :step1
      end

     event :escrow_tx_received do
       transitions :from => :step1, :to => :step2
     end

     event :beta_values_sent do
       transitions :from => :step2, :to => :step4
     end

     event :c_z_values_received do
       transitions :from => :step4, :to => :step6
     end

     event :real_indices_sent do
       transitions :from => :step6, :to => :step7
     end

     event :fake_epsilons_received do
       transitions :from => :step7, :to => :step8
     end
     
     event :quotients_received do
        transitions :from => :step8, :to => :step10
      end
      
      event :escrow_tx_broadcasted do
        transitions :from => :step10, :to => :completed
      end
   end
  
  validates_presence_of :title
  validates :expiry_date, :timeliness => {:type => :datetime }
  
  attr_accessor :tx_hash, :index, :amount, :confirmations, :signed_tx
  
  require 'btcruby/extensions'
  require 'money-tree'
  require 'mechanize'
  require 'digest'
  
  self.per_page = 10
  
  
  def bob_public_key
    unless self.key_path.blank? 
      keychain = BTC::Keychain.new(xpub:Figaro.env.bob_mpk) 
      keychain.derived_keychain(self.key_path).key.public_key.unpack('H*')[0]
    else
      ""
    end
  end
  
  
  def real_btc_tx_sighash(i)
    # @tumbler_key=BTC::Key.new(public_key:BTC.from_hex(self.tumbler_key))
    # keychain = BTC::Keychain.new(xprv:Figaro.env.tumbler_btc_mpk)  # TODO: replace with Bob's mpk
    keychain = BTC::Keychain.new(xpub:Figaro.env.bob_mpk) 
    salt = Figaro.env.tumblebit_salt
    index = (salt.to_i + self.id.to_i + i.to_i) % 0x80000000
    key = keychain.derived_keychain("8/#{index}").key
    @previous_id = "d569e96b0d88b3774de1e4fe1a7e9ce8e07d362af8afa4d960ca0514b51fb4f9"
    @previous_index = 0
    @value = 265800 - $NETWORK_FEE # in satoshis
    tx = BTC::Transaction.new
    tx.lock_time = 1471199999 # some time in the past (2016-08-14)
    tx.add_input(BTC::TransactionInput.new( previous_id: @previous_id, # UTXO is "escrow" P2SH funded by Tumbler
                                            previous_index: @previous_index,
                                            sequence: 0))
    tx.add_output(BTC::TransactionOutput.new(value: @value, script: key.address.script))
    hashtype = BTC::SIGHASH_ALL
    sighash = tx.signature_hash(input_index: 0,
                                output_script: self.funding_script,
                                hash_type: hashtype)
    beta = sighash.unpack('H*')[0]
  end
  
  
  def fake_btc_tx_sighash(i)
    @user_key=BTC::Key.new(public_key:BTC.from_hex(self.bob_public_key))
    if self.r
      r = self.r.to_i
    else
      r = Random.new.bytes(32).unpack('H*')[0].to_i(16) # 256-bit random integer
      self.r = r
      self.save
    end
    index = r+i
    @previous_id = "d569e96b0d88b3774de1e4fe1a7e9ce8e07d362af8afa4d960ca0514b51fb4f9" # TODO make it a variable
    @previous_index = 0
    @value = 265800 - $NETWORK_FEE# in satoshis
    hashtype = BTC::SIGHASH_ALL
    @op_return_script = BTC::Script.new(op_return: index.to_s)
    tx = BTC::Transaction.new
    tx.lock_time = 1471199999 # some time in the past (2016-08-14)
    tx.add_input(BTC::TransactionInput.new( previous_id: @previous_id, # UTXO is "escrow" P2SH funded by Tumbler
                                          previous_index: @previous_index,
                                          sequence: 0))
    tx.add_output(BTC::TransactionOutput.new(value: @value, script: @user_key.address.script))
    tx.add_output(BTC::TransactionOutput.new(value: 0, script: @op_return_script))

    hashtype = BTC::SIGHASH_ALL
    sighash = tx.signature_hash(input_index: 0,
                                output_script: self.funding_script,
                                hash_type: hashtype)
    beta = sighash.unpack('H*')[0]
  end
  
  
  def description
        "        IF 
        2 <Tumbler> <Bob> 2 CHECKMULTISIG
        ELSE 
        <expiry time> CHECKLOCKTIMEVERIFY DROP
        <Tumbler> CHECKSIG
        ENDIF"
  end
  
  
  def funding_script
    BTC::Network.default= BTC::Network.mainnet
    @funding_script = BTC::Script.new

    @tumbler_key=BTC::Key.new(public_key:BTC.from_hex(self.tumbler_public_key))
    @user_key=BTC::Key.new(public_key:BTC.from_hex(self.bob_public_key))
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
        
    # return @funding_script
  end
  
  
  def hash_address
    # compute P2SH address for self.funding_script
    bob_public_key = self.bob_public_key
    tumbler_public_key = self.tumbler_public_key
    if (bob_public_key.blank? or tumbler_public_key.blank? )
      return nil # Script to Hash Address requires 2 keys.
    else
      funded_address=BTC::ScriptHashAddress.new(redeem_script:self.funding_script, network:BTC::Network.default)
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
      string = $BLOCKR_ADDRESS_UNSPENT_URL + self.hash_address.to_s + "?unconfirmed=1"
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
    if self.expiry_date
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
      self.amount = result['data']['unspent'][0]['amount'] # amount in BTC
      self.confirmations = result['data']['unspent'][0]['confirmations']
      puts "Tx hash: #{self.tx_hash}"
      return true
    else
      puts "No utxo avalaible for #{self.hash_address}"
      return false
    end
  end
  
  
end