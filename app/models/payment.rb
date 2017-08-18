class Payment < ActiveRecord::Base
  
  include AASM

  aasm do # default column: aasm_state
    state :initiated, :initial => true
    state :step1,:step3,:step5,:step7,:step8
    state :completed

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
  
  require 'btcruby/extensions'
  require 'money-tree'
  require 'mechanize'
  require 'digest'
  
  
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
      puts "No spending transaction for #{self.hash_address}"
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
    result = JSON.parse(data)
    puts result
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
      puts "Tx hash: #{self.tx_hash}"
      return self.tx_hash
    else
      puts "No spending transaction for #{self.hash_address}"
      return nil
    end
  end
  
  
  def generate_beta_values
    # Fig. 3, steps 1,2,3
    # Alice creates 300 values for Tumbler, mixing 15 real values with 285 fake values
    @script =Script.find(self.script_id)
    string = self.funded_address

    if self.real_indices.blank?
      real_indices = []
      prng = Random.new
      while real_indices.count < 15
        j = prng.rand(0..299)
        unless real_indices.include? j
          real_indices << j
        end
      end
      self.real_indices = real_indices
      self.save # save indices of real values to @payment.real_indices
    end
    puts "Real indices: #{self.real_indices}"

    # Exponent (part of the public key)
    e = $TUMBLER_RSA_PUBLIC_EXPONENT
    # The modulus (aka the public key, although this is also used in the private key computations as well)
    n = $TUMBLER_RSA_PUBLIC_KEY

    salt=Random.new.bytes(32).unpack('H*')[0] # 256-bit random integer
    puts "Salt: #{salt}"
    r=[]
    real = []
    self.real_indices.each do |ri|
      real << ri.strip # avoid problems with extra leading or trailing space caracters
    end

    for i in 0..299  # create 300 blinding factors
      # 285 ro values created by Alice
      # 15 r values created by Bob. Alice knows only d = y*r^^pk
      if real.include? i.to_s
        r[i]=Random.new.bytes(10).unpack('H*')[0] # "8f0722a18b63d49e8d9a", size = 20 hex char, 80 bits, 10 bytes
      else
        r[i]=(Random.new.bytes(10).unpack('H*')[0].to_i(16)*salt.to_i(16) % n).to_s(16) # salt is same size as epsilon, otherwise Tumbler can easily tell real values from fake values based on the size of s
      end
    end


    # dump the 285 values to ro_values
    @ro_values = []
    for i in 0..299
      unless real.include? i.to_s
        @ro_values[i] = r[i]
      end
    end

    @beta_values = []
    # first, compute 15 real beta values

    p = self.y.to_i  # y = epsilon^^pk
    # The secret exponent (aka the private key)
    d = Figaro.env.tumbler_rsa_private_key.to_i(16)
    epsilon = mod_pow(p,d,n)
    puts "y: #{self.y.to_i.to_s(16)}"
    puts "Epsilon: #{epsilon.to_s(16)}"
    puts "Epsilon in db: #{@script.contract}"

    m = @script.contract.to_i(16)
    puzzle = mod_pow(m,e,n) # epsilon^pk mod n
    puts "puzzle: %x" % puzzle

    # puzzle solution
    d = Figaro.env.tumbler_rsa_private_key.to_i(16)
    solution = mod_pow(puzzle,d,n) # puzzle^sk mod modulus
    puts "Solution (epsilon):" + solution.to_s(16)
    puts "Script contract:" + @script.contract # solution should be equal to contract


    real.each do |i|
      m = r[i.to_i].to_i(16)
      b = mod_pow(m,e,n)
      beta_value = (p*b) % n
      @beta_values[i.to_i] = beta_value.to_s(16)
    end

    # compute 285 fake values to complete beta_values
    k = 0
    for i in 0..299
      if @beta_values[i].blank?
        m = r[i].to_i(16)
        beta_value = mod_pow(m,e,n)
        @beta_values[i] = beta_value.to_s(16)
        k += 1
      end
    end
    puts "Number of fake values: #{k}"
    puts "Total number of values: #{@beta_values.count}"
    @beta_values
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
  
  
end
