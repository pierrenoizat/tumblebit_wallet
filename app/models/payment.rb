class Payment < ActiveRecord::Base
  
  include AASM

  aasm do # default column: aasm_state
    state :initiated, :initial => true
    state :step1,:step5,:step7,:step8
    state :completed

    event :y_received do
      transitions :from => :initiated, :to => :step1
    end

    event :beta_values_sent do
      transitions :from => :step1, :to => :step5
    end
    
    event :c_h_values_received do
      transitions :from => :step5, :to => :step7
    end
    
    event :fake_k_values_received do
      transitions :from => :step7, :to => :step8
    end
    
    event :solve_tx_broadcasted do
      transitions :from => :step8, :to => :completed
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
  
  
  def hash_address
    unless self.tumbler_public_key.blank?
      @funded_address=BTC::ScriptHashAddress.new(redeem_script:self.funding_script, network:BTC::Network.default)
    else
      @funded_address = nil
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
        puts "#{h[i]}"
        @funding_script<<BTC::Script::OP_EQUALVERIFY
        j+=1
      end
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
  end
  
  
  def puzzle_transaction_address
    unless self.puzzle_transaction_script.blank?
      BTC::ScriptHashAddress.new(redeem_script:self.puzzle_transaction_script, network:BTC::Network.default)
    else
      return nil
    end
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
  
end
