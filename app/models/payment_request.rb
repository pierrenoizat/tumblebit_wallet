class PaymentRequest < ActiveRecord::Base
  include Crypto # module in /lib
  include AASM

   aasm do # default column: aasm_state
     state :started, :initial => true
     state :step1, :step2,:step4, :step6,:step7,:step8,:step10, :step12
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
        transitions :from => :step10, :to => :step12
      end
      
      event :puzzle_solution_received do
          transitions :from => :step12, :to => :completed
        end
      
   end
  
  validates :expiry_date, :timeliness => {:type => :datetime }
  validates :key_path, :expiry_date, :title, :r, :blinding_factor, presence: true
  validates :tumbler_public_key, uniqueness: { case_sensitive: false }
  
  attr_accessor :signed_tx
  
  require 'btcruby/extensions'
  require 'money-tree'
  require 'mechanize'
  require 'digest'
  
  self.per_page = 10
  
  
  def init
    self.expiry_date  ||= Time.now.utc  # will set the default value only if it's nil
    r = Random.new.bytes(32).unpack('H*')[0].to_i(16) # 256-bit random integer
    self.r = r
    self.blinding_factor = Random.new.bytes(32).unpack('H*')[0].to_i(16)
    real_indices = []
    prng = Random.new
    while real_indices.count < 42
      j = prng.rand(0..83)
      unless real_indices.include? j
        real_indices << j
      end
    end
    self.real_indices ||= real_indices.sort
    
    salt = Figaro.env.tumblebit_salt
    index = (salt.to_i + prng.rand(0..99999)) % 0x80000000
    self.key_path = "1/#{index}"
  end
  
  
  def bob_private_key
    keychain = BTC::Keychain.new(xprv:Figaro.env.bob_msk)
    keychain.derived_keychain(self.key_path).key.to_wif # compressed wif
  end
  
  
  def bob_public_key
    unless self.key_path.blank? 
      keychain = BTC::Keychain.new(xpub:Figaro.env.bob_mpk) 
      keychain.derived_keychain(self.key_path).key.public_key.unpack('H*')[0]
    else
      ""
    end
  end
  
  
  def real_btc_tx_sighash(i)
    BTC::Network.default = BTC::Network.mainnet
    # For testing, replaced funding_script by @tumbler_funded_address P2PKH script
    # @previous_id points to UTXO funded by Tumbler on static address 

    # TODO: @previous_id should point dynamically to 2-of-2 multisig with timelocked refund P2SH escrow UTXO

    # @bob_key = BTC::Key.new(public_key:BTC.from_hex(self.bob_public_key))
    # @bob_payout_address = @bob_key.address.to_s # test: paying back Tumbler instead of Bob
    
    keychain = BTC::Keychain.new(xpub:Figaro.env.bob_mpk)
    path = self.key_path[0...-2] + i.to_s

    @bob_key = BTC::Key.new(public_key:BTC.from_hex(keychain.derived_keychain(path).key.public_key.unpack('H*')[0]))
    @bob_payout_address = @bob_key.address.to_s 

    @tumbler_funded_address = Figaro.env.tumbler_funding_address # static 1LUBfiVgeuFRzc7PC1Auw8YAncdewderVg, TODO : dynamic generation
    @tumbler_key = BTC::Key.new(wif: Figaro.env.tumbler_funding_priv_key)
    @previous_id = self.tx_hash
    @previous_index = self.index 
    @value = (self.amount.to_f - 200*$FEE_RATE)
    tx = BTC::Transaction.new
    tx.lock_time = 1471199999 # some time in the past (2016-08-14)
    tx.add_input(BTC::TransactionInput.new( previous_id: @previous_id,
                                            previous_index: @previous_index,
                                            sequence: 0))
    # tx.add_output(BTC::TransactionOutput.new(value: @value, script: key.address.script))
    tx.add_output(BTC::TransactionOutput.new(value: @value, script: BTC::Address.parse(@bob_payout_address).script))
    hashtype = BTC::SIGHASH_ALL
    # signature_hash : specify an input index (0) and output script of the previous transaction for that input
    sighash = tx.signature_hash(input_index: 0,
                                output_script: BTC::Address.parse(@tumbler_funded_address).script,
                                hash_type: hashtype)
    beta = sighash.unpack('H*')[0]
             
  end # of real_btc_tx_sighash intance method
  
  
  def payout_address
    keychain = BTC::Keychain.new(xpub:Figaro.env.bob_mpk)
    i = self.real_indices.first
    path = self.key_path[0...-2] + i.to_s
    @bob_key = BTC::Key.new(public_key:BTC.from_hex(keychain.derived_keychain(path).key.public_key.unpack('H*')[0]))
    @bob_key.address.to_s
  end
  
  
  def payout_tx
    
    # TODO for testing replace funding_script by @tumbler_funded_address P2PKH script
    # BTC::Script "OP_DUP OP_HASH160 7ab89f9fae3f8043dcee5f7b5467a0f0a6e2f7e1 OP_EQUALVERIFY OP_CHECKSIG"
    
    # Payout transaction that pays Bob , spending from tx funded by Tumbler, using Tumbler signature sigma
    # Compute sigma by decrypting c with key epsilon ( σ = Hprg(ε) ⊕ c )
    
    # @tumbler_key=BTC::Key.new(public_key:BTC.from_hex(self.tumbler_key))
    # keychain = BTC::Keychain.new(xprv:Figaro.env.tumbler_btc_mpk)
    epsilon = (self.solution.to_i(16)/self.blinding_factor.to_i).to_s(16)
    
    decipher = OpenSSL::Cipher::AES.new(128, :CBC)
    decipher.decrypt

    key = epsilon.htb
    iv_hex = $AES_INIT_VECTOR
    iv = iv_hex.htb
    i = self.real_indices.first
    encrypted = self.c_values[i].htb
    decipher.key = key
    decipher.iv = iv

    plain = decipher.update(encrypted) + decipher.final  # Tumbler signature
    sigma = BTC::Data.hex_from_data(plain)
    
    @tumbler_funded_address = Figaro.env.tumbler_funding_address # static 1LUBfiVgeuFRzc7PC1Auw8YAncdewderVg, TODO : dynamic generation
    @tumbler_key = BTC::Key.new(wif: Figaro.env.tumbler_funding_priv_key)
    
    # scriptSig (escrow tx before expiry): 0 <Tumbler signature> <Bob signature> TRUE
    @previous_id = self.tx_hash
    @previous_index = self.index 
    # @value = ( self.amount.to_f*BTC::COIN ).to_i - 40000 # in satoshis, self.amount MUST be 500 000 satoshis ( ~ 2 € )
    @value = (self.amount.to_f - 200*$FEE_RATE) # @value is expressed in satoshis, should be 450 000
    tx = BTC::Transaction.new
    tx.lock_time = 1471199999 # some time in the past (2016-08-14)
    tx.add_input(BTC::TransactionInput.new( previous_id: @previous_id, # UTXO is "escrow" P2SH funded by Tumbler
                                            previous_index: @previous_index,
                                            sequence: 0))
    # tx.add_output(BTC::TransactionOutput.new(value: @value, script: key.address.script))
    tx.add_output(BTC::TransactionOutput.new(value: @value, script: BTC::PublicKeyAddress.new(string: self.payout_address).script))
    hashtype = BTC::SIGHASH_ALL
    sighash = tx.signature_hash(input_index: 0,
                                output_script: BTC::PublicKeyAddress.new(string:@tumbler_funded_address).script,
                                hash_type: hashtype)
    tx.inputs[0].signature_script = BTC::Script.new << (sigma.htb + BTC::WireFormat.encode_uint8(hashtype)) << @tumbler_key.public_key
    return tx.to_s
    
  end # of payout_tx instance method
  
  
  def fake_btc_tx_sighash(i)
    @user_key=BTC::Key.new(public_key:BTC.from_hex(self.bob_public_key))
    r = self.r.to_i
    index = r+i
    @previous_id = "d569e96b0d88b3774de1e4fe1a7e9ce8e07d362af8afa4d960ca0514b51fb4f9" # TODO make it a variable
    @previous_index = 0
    # @value = $AMOUNT - $NETWORK_FEE # in satoshis 
    @value = 19800000
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
  
  
  def funding_script # simplified script paying user (Bob) without escrow
    # TODO : make it dynamic instead of static
    BTC::Network.default= BTC::Network.mainnet
    # @funding_script = BTC::Script.new

    # @funding_script = BTC::Script.new(hex: "76a914d58e8690c8cda5719ac5a1d2cacfc9f66ea9653c88ac")
    # @funding_script.standard_address
    # => #<BTC::PublicKeyAddress:1LUBfiVgeuFRzc7PC1Auw8YAncdewderVg>
    @tumbler_funded_address = Figaro.env.tumbler_funding_address # static 1LUBfiVgeuFRzc7PC1Auw8YAncdewderVg, TODO : dynamic generation
    @funding_script = BTC::PublicKeyAddress.new(string:@tumbler_funded_address).script
  end
  
  
  def funding_script_original # TODO: original tumblebit script with escrow
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
  end
  
  
  def hash_address
    if self.bob_public_key.blank?
      return nil
    else
      funded_address = self.funding_script.standard_address
    end
  end
  
  
  def hash_address_original
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
      i = 0
      while i < result['data']['unspent'].count
        if ( result['data']['unspent'][i]['amount'].to_f == 0.005 and self.tx_hash.blank? )
          self.tx_hash = result['data']['unspent'][i]['tx']
          self.index = result['data']['unspent'][i]['n'].to_i
          self.amount = result['data']['unspent'][i]['amount'].to_f # amount in BTC
          self.confirmations = result['data']['unspent'][i]['confirmations'].to_i
          puts "Tx hash: #{self.tx_hash}"
        end
        i += 1
      end
      return self.tx_hash
    else
      puts "No utxo avalaible for #{address}"
      return nil
    end
  end
  
  
  def real_z_values
    @real_z_values = []
    for i in 0..83
      if self.real_indices.include? i
        @real_z_values << self.z_values[i]
      end
    end
    @real_z_values
  end
  
  
  def y
    e = $TUMBLER_RSA_PUBLIC_EXPONENT
    n = $TUMBLER_RSA_PUBLIC_KEY
    # Bob's blinding factor R in step 12
    blinding_factor = self.blinding_factor.to_i
    y = self.real_z_values[0].to_i(16)*mod_pow(blinding_factor, e, n) % n
    y.to_s(16)
  end
  
  
  def quotients_ok?
    quotients_ok = false
    # In step 10, Bob computes zj1*(q2)pk = (epsilonj2)pk and checks that zj2 = zj1*(q2)pk
    # If any check fails, Bob aborts the protocol.
    # If no fail, Tumbler is very likely to have sent validly formed zi values.
    e = $TUMBLER_RSA_PUBLIC_EXPONENT
    n = $TUMBLER_RSA_PUBLIC_KEY
    @quotients = self.quotients
    @real_z_values = self.real_z_values
    j = 0

    puts "Number of real z values : " + @real_z_values.count.to_s
    puts "check that z2 = z1*(q2)^pk mod n"

    j = 0
    for i in 0..40
      z2 = @real_z_values[i+1].to_i(16)
      z1 = @real_z_values[i].to_i(16)
      q2 = @quotients[i].to_i(16)
      puts z2.to_s(16)
      puts z1.to_s(16)
      puts q2
      if (z2 == (z1*mod_pow(q2, e, n) % n))
        j += 1
      else
        puts "Failed test, should be zero:" + ((z2 - z1*mod_pow(q2, e, n)) % n).to_s
      end
      puts j
    end
    quotients_ok = ( j == 41 )
  end
  
  
end
