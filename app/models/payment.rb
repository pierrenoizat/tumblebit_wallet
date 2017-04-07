class Payment < ActiveRecord::Base
  
  include AASM

  aasm do # default column: aasm_state
    state :initiated, :initial => true
    state :step1,:step4, :step5,:step6,:step8, :step9
    state :completed

    event :y_received do
      transitions :from => :initiated, :to => :step1
    end

    event :beta_values_sent do
      transitions :from => :step1, :to => :step4
    end
    
    event :c_h_values_received do
      transitions :from => :step4, :to => :step5
    end
    
    event :ro_values_sent do
      transitions :from => :step5, :to => :step6
    end
    
    event :k_values_received do
      transitions :from => :step6, :to => :step8
    end
    
    event :y_sent do
      transitions :from => :step8, :to => :step9
    end
    
    event :solve_tx_broadcasted do
      transitions :from => :step9, :to => :completed
    end
  end
  
  include Crypto # module in /lib
  
  attr_accessor :solution
  
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
    @tumbler_key=BTC::Key.new(public_key:BTC.from_hex(self.tumbler_public_key))
    @user_key=BTC::Key.new(public_key:BTC.from_hex(self.alice_public_key))

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
  
  
  def funded_address
    unless (self.tumbler_public_key.blank? or self.alice_public_key.blank?)
      @funded_address=BTC::ScriptHashAddress.new(redeem_script:self.funding_script, network:BTC::Network.default)
    else
      @funded_address = nil
    end
  end
  
  def generate_epsilon_values
    # Tumbler picks 300 128-bit epsilon values with epsilon < n, RSA public key modulus of Tumbler.
    epsilon = []
    n = $TUMBLER_RSA_PUBLIC_KEY.to_i
    k = 0
    300.times do
      value = n
      while (value >= n)
        value = Random.new.bytes(16).unpack('H*')[0].to_i(16) # 128-bit random integer
        k += 1
      end
      epsilon << value.to_s(16)
    end
    epsilon # returns array of 300 values (hex strings)
    puts "Epsilon: #{epsilon[0]}"
    z = generate_z(epsilon[0])
    generate_blinded_puzzle(z)
  end
  
  
  def generate_z(epsilon)
    # returns puzzle z = (epsilon)**pk where pk is Tumbler RSA public key
    # Exponent (part of the public key)
    e = $TUMBLER_RSA_PUBLIC_EXPONENT
    # The modulus (aka the public key, although this is also used in the private key computations as well)
    n = $TUMBLER_RSA_PUBLIC_KEY
    z = mod_pow(epsilon.to_i(16),e,n) # epsilon^pk mod n
    puts "z: #{z.to_s(16)}"
    z
  end
  
  def generate_blinded_puzzle(z)
    e = $TUMBLER_RSA_PUBLIC_EXPONENT
    n = $TUMBLER_RSA_PUBLIC_KEY.to_i
    r = Random.new.bytes(16).unpack('H*')[0].to_i(16) # 128-bit random integer, Bob keeps it secret
    big_r = mod_pow(r,e,n) # r^pk mod n
    puts "R: #{r.to_s(16)}"
    blinded_puzzle = big_r*z % n
    puts "Blinded puzzle: #{blinded_puzzle.to_s(16)}" 
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
  
end
