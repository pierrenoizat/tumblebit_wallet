class Payment < ActiveRecord::Base
  include Paymentable
  include Crypto # module in /lib
  include AASM

  aasm do # default column: aasm_state
    state :initiated, :initial => true
    state :step1,:step3,:step5,:step7,:step8, :completed

    event :y_received do
      transitions :from => :initiated, :to => :step1
    end

    event :beta_values_sent do
      transitions :from => :step1, :to => :step3
    end
    
    event :c_h_values_received do
      transitions :from => :step3, :to => :step5
    end
    
    event :fake_k_values_checked do
      transitions :from => :step5, :to => :step7
    end
    
    event :y_value_sent do
      transitions :from => :step7, :to => :step8
    end
    
    event :real_k_values_obtained do
      transitions :from => :step8, :to => :completed
    end
  end
  
  include Crypto # module in /lib
  
  attr_accessor :tx_hash, :index, :amount, :confirmations, :signed_tx, :secret
  # after_initialize :init
  validates :expiry_date, :timeliness => {:type => :datetime }
  validates :tumbler_public_key, :key_path, :expiry_date, presence: true
  validates :tumbler_public_key, uniqueness: { case_sensitive: false }
  
  require 'btcruby/extensions'
  require 'money-tree'
  require 'digest'
  
  
  def puzzle_transaction
    # Alice step 8
    # Tpuzzle offers 1 bitcoin within timewindow tw1 under condition:
    # the fulfilling transaction is signed by T and has preimages of hj ∀j ∈ R
  end
  
  
  def init
    self.expiry_date  ||= Time.now.utc  # will set the default value only if it's nil
    real_indices = []
    prng = Random.new
    while real_indices.count < 15
      j = prng.rand(0..299)
      unless real_indices.include? j
        real_indices << j
      end
    end
    self.real_indices ||= real_indices.sort
    
    salt = Figaro.env.tumblebit_salt
    index = (salt.to_i + prng.rand(0..99999)) % 0x80000000
    self.key_path = "1/#{index}"
  end
  
  
  def alice_private_key
    keychain = BTC::Keychain.new(xprv:Figaro.env.alice_msk)
    keychain.derived_keychain(self.key_path).key.to_wif # compressed wif
  end
  
  
  def alice_public_key
    unless self.key_path.blank? 
      keychain = BTC::Keychain.new(xpub:Figaro.env.alice_mpk) 
      keychain.derived_keychain(self.key_path).key.public_key.unpack('H*')[0]
    else
      ""
    end
  end
  
  
  def self.search(query)
    where("y like ?", "%#{query}%") 
  end
  
  
  def funding_script
    BTC::Network.default= BTC::Network.mainnet
    @funding_script = BTC::Script.new
    if !self.tumbler_public_key.blank? and !self.alice_public_key.blank?
      @tumbler_key=BTC::Key.new(public_key:BTC.from_hex(self.tumbler_public_key))
      @user_key=BTC::Key.new(public_key:BTC.from_hex(self.alice_public_key))
    
      @expire_at = Time.at(self.expiry_date.to_time.to_i)
      if !self.h_values.blank?
        @funding_script<<BTC::Script::OP_IF
        for i in 0..299
          if self.real_indices.include? i
            @funding_script<<BTC::Script::OP_RIPEMD160
            @funding_script.append_pushdata(BTC::Data.data_from_hex(self.h_values[i]))
            @funding_script<<BTC::Script::OP_EQUALVERIFY
          end
        end
        @funding_script<<@tumbler_key.compressed_public_key
        @funding_script<<BTC::Script::OP_CHECKSIG
        @funding_script<<BTC::Script::OP_ELSE
        @funding_script<<BTC::WireFormat.encode_int32le(@expire_at.to_i)
        @funding_script<<BTC::Script::OP_CHECKLOCKTIMEVERIFY
        @funding_script<<BTC::Script::OP_DROP
        @funding_script<<@user_key.compressed_public_key
        @funding_script<<BTC::Script::OP_CHECKSIG
        @funding_script<<BTC::Script::OP_ENDIF
      else
        return nil
      end
    else
      return nil
    end
  end
  
  
  def hash_address
    if self.funding_script
      BTC::ScriptHashAddress.new(redeem_script:self.funding_script, network:BTC::Network.default)
    else
      return nil
    end
  end
  
  
  def puzzle_transaction_script
    @tumbler_key=BTC::Key.new(public_key:BTC.from_hex(self.tumbler_public_key))
    @alice_key=BTC::Key.new(public_key:BTC.from_hex(self.alice_public_key))
    
    
    @expire_at = Time.at(self.expiry_date.to_time.to_i)
    h = Array.new
    BTC::Network.default= BTC::Network.mainnet
    @funding_script = BTC::Script.new
    
    unless self.h_values.blank?
      for i in 0..299
        if self.real_indices.include? i
          h << self.h_values[i]
        end
      end
      @funding_script<<BTC::Script::OP_IF
      j=0
      for i in 0..14
        # self.update(contract: h[i])
        @funding_script<<BTC::Script::OP_RIPEMD160
        @funding_script.append_pushdata(BTC::Data.data_from_hex(h[i]))
        @funding_script<<BTC::Script::OP_EQUALVERIFY
        j+=1
      end
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
  end
  
  
  def puzzle_transaction_address
    unless self.puzzle_transaction_script.blank?
      BTC::ScriptHashAddress.new(redeem_script:self.puzzle_transaction_script, network:BTC::Network.default)
    else
      return nil
    end
  end
  
  
  def puzzle_transaction
    @alice_key = BTC::Key.new(wif:self.alice_private_key)
    @alice_funded_address = @alice_key.address.to_s
    @previous_id = self.first_unspent_tx(@alice_funded_address)
    @previous_index = self.index
    # @value = (self.amount.to_f * BTC::COIN).to_i - $NETWORK_FEE # in satoshis, amount MUST be 200 000 satoshis (~ 2 €)
    @value = (self.amount.to_f * BTC::COIN).to_i - 40000
    BTC::Network.default = BTC::Network.mainnet
    @funding_script = BTC::Script.new
    @funding_script = BTC::PublicKeyAddress.new(key:@alice_key).script

    tx = BTC::Transaction.new
    tx.lock_time = 1471199999 # some time in the past (2016-08-14)
    tx.add_input(BTC::TransactionInput.new( previous_id: @previous_id, # UTXO has been funded by Alice
                                            previous_index: @previous_index,
                                            sequence: 0))
    tx.add_output(BTC::TransactionOutput.new(value: @value, 
                                            script: BTC::Address.parse(self.puzzle_transaction_address).script))
    hashtype = BTC::SIGHASH_ALL
    sighash = tx.signature_hash(input_index: 0,
                                output_script: BTC::PublicKeyAddress.new(string:@alice_funded_address).script,
                                hash_type: hashtype)
    tx.inputs[0].signature_script = BTC::Script.new    
    @alice_key = BTC::Key.new(wif:self.alice_private_key)   
    tx.inputs[0].signature_script << (@alice_key.ecdsa_signature(sighash) + BTC::WireFormat.encode_uint8(hashtype))
    tx.inputs[0].signature_script << @alice_key.compressed_public_key
    return tx.to_s
  end
  
  
  def real_btc_tx_sighash(i)
    @tumbler_key=BTC::Key.new(public_key:BTC.from_hex(self.tumbler_public_key))
    keychain = BTC::Keychain.new(xprv:Figaro.env.tumbler_btc_msk)
    salt = Figaro.env.tumblebit_salt
    index = (salt.to_i + self.id.to_i + i.to_i) % 0x80000000
    key = keychain.derived_keychain("8/#{index}").key
    @previous_id = self.tx_hash
    @previous_index = 0
    @value = self.amount - $NETWORK_FEE # in satoshis
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
    @tumbler_key=BTC::Key.new(public_key:BTC.from_hex(self.tumbler_public_key))
    if self.r
      r = self.r.to_i
    else
      r = Random.new.bytes(32).unpack('H*')[0].to_i(16) # 256-bit random integer
      self.r = r
      self.save
    end
    index = r+i
    @previous_id = self.tx_hash
    @previous_index = 0
    @value = self.amount
    hashtype = BTC::SIGHASH_ALL
    @op_return_script = BTC::Script.new(op_return: index.to_s)
    tx = BTC::Transaction.new
    tx.lock_time = 1471199999 # some time in the past (2016-08-14)
    tx.add_input(BTC::TransactionInput.new( previous_id: @previous_id, # UTXO is "escrow" P2SH funded by Tumbler
                                          previous_index: @previous_index,
                                          sequence: 0))
    tx.add_output(BTC::TransactionOutput.new(value: @value, script: @tumbler_key.address.script))
    tx.add_output(BTC::TransactionOutput.new(value: 0, script: @op_return_script))

    hashtype = BTC::SIGHASH_ALL
    sighash = tx.signature_hash(input_index: 0,
                                output_script: self.funding_script,
                                hash_type: hashtype)
    beta = sighash.unpack('H*')[0]
  end 
  
  
  def expired?
      return (Time.now.to_i > self.expiry_date.to_i)
  end
  
  
  def utxo(address)
    utxo_params = Hash.new
    
    string = $BLOCKCHAIN_UTXO_URL + address.to_s
    @agent = Mechanize.new
    begin
    page = @agent.get string
    rescue Exception => e
    page = e.page
    end

    data = page.body
    result = JSON.parse(data)
    self.tx_hash = nil
    if !result['unspent_outputs'].blank?
      result['unspent_outputs'].each do |utx|
        if utx['value'].to_f >= 450000
          self.tx_hash = utx['tx_hash_big_endian']
          self.index = utx['tx_output_n'].to_i
          self.amount = utx['value'].to_f
          self.confirmations = utx['confirmations'].to_i
          utxo_params["tx_hash"] = utx['tx_hash_big_endian']
          utxo_params["index"]  = utx['tx_output_n'].to_i
          utxo_params["amount"]  = utx['value'].to_f  # amount in satoshis
          utxo_params["confirmations"]  = utx['confirmations'].to_i
        end
      end
      return utxo_params
    else
      puts "No utxo avalaible for #{address}"
      return nil
    end
  end # of model method utxo
  
  
  def first_spending_tx_hash_unconfirmed
    require 'blockcypher'
    block_cypher = BlockCypher::Api.new(api_token:Figaro.env.blockcypher_api_token)
    puts "Total received = #{block_cypher.address_full_txs(self.hash_address.to_s)['total_received']}"
    puts "Total nb of unconfirmed = #{block_cypher.address_full_txs(self.hash_address.to_s)['unconfirmed_n_tx']}"

    i = 0
    while i < block_cypher.address_details(self.hash_address.to_s)['n_tx']
      if block_cypher.address_details(self.hash_address.to_s)['txrefs'][i]['tx_input_n'] >= 0
        puts "Output index = #{block_cypher.address_details(self.hash_address.to_s)['txrefs'][i]['tx_input_n'] }"
        self.tx_hash = block_cypher.address_details(self.hash_address.to_s)['txrefs'][i]['tx_hash']
        i = 200
      else
        i += 1
      end
    end
    if self.tx_hash
      puts "Tx hash: #{self.tx_hash}"
      return self.tx_hash
    else
      puts "No spending transaction for #{self.hash_address} at BlockCypher"
      return nil
    end
  end
  
  
  def first_spending_tx_hash
    
    string = "http://btc.blockr.io/api/v1/address/txs/" + self.hash_address.to_s + "?unconfirmed=1" 

    @agent = Mechanize.new

    begin
    page = @agent.get string
    rescue Exception => e
    page = e.page
    end

    data = page.body
    if valid_json?(data)
      result = JSON.parse(data)
      if !result['data']['txs'].blank?
        i = 0
        counter = result['data']['txs'].count
        while i < counter
          if result['data']['txs'][i]['amount'] < 0
            self.tx_hash = result['data']['txs'][0]['tx']
            i = counter
          else
            i += 1
          end
        end
        puts "According to Blockr.io, Tx hash: #{self.tx_hash}"
      else
        puts "No spending transaction for #{self.hash_address} at Blockr.io"
      end
    else # blockr.io not available, trying blockchain.info
      puts "blockr.io not available, trying blockchain.info"
      string = "https://blockchain.info/rawaddr/" + self.hash_address.to_s
      begin
        page = @agent.get string
      rescue Exception => e
        page = e.page
      end

      data = page.body
      result = JSON.parse(data)
      n = result["n_tx"]
      i = 0
      while i < n
        tx = result["txs"][i]
        if tx["inputs"][0]["prev_out"]["addr"] == self.hash_address.to_s
          self.tx_hash = tx["hash"]
          puts "According to Blockchain.info, Tx hash: #{self.tx_hash}"
          i = n
        else
          i += 1
        end
      end
    end
    puts "Hash of tx paying Tumbler: #{self.tx_hash}"
    self.tx_hash
    
  end
  
  
  def ro_values
    @ro_values = Array.new
    if !self.r_values.blank?
      for i in 0..299  # select 285 fake blinding factors ro
        if self.real_indices.include? i
          @ro_values[i] = nil
        else
          @ro_values[i] = self.r_values[i]
        end
      end
    end
    @ro_values
  end
  
  
  def real_c_values
    real_c = []
    unless self.c_values.blank?
      for i in 0..299
        if self.real_indices.include? i
          real_c << self.c_values[i]
        end
      end
    end
    real_c
  end
  
  
  def real_beta_values
    real_beta = []
    unless self.beta_values.blank?
      for i in 0..299
        if self.real_indices.include? i
          real_beta << self.beta_values[i]
        end
      end
    end
    real_beta
  end
  
  
  def real_r_values
    real_r = []
    unless self.r_values.blank?
      for i in 0..299
        if self.real_indices.include? i
          real_r << self.r_values[i]
        end
      end
    end
    real_r
  end
  
  
  def first_unspent_tx(address)
    string = $BLOCKR_ADDRESS_UNSPENT_URL + address + "?unconfirmed=1" # with_unconfirmed
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
      self.index = result['data']['unspent'][0]['n'].to_i
      self.amount = result['data']['unspent'][0]['amount'].to_f # amount in BTC
      self.confirmations = result['data']['unspent'][0]['confirmations'].to_i
      puts "Tx hash: #{self.tx_hash}"
      return self.tx_hash
    else
      puts "No utxo avalaible for #{address}"
      return nil
    end
  end
  
  def valid_y?
    valid = false
    hex_pattern = /^[[:xdigit:]]+$/ # is y a hex string ?
    if !self.y.blank?
      valid = ((self.y.size == 256) and hex_pattern === self.y )
    end
    valid
  end
  
  
end
