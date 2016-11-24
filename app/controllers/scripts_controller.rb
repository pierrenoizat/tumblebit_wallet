class ScriptsController < ApplicationController
  before_filter :authenticate_user!, :except => [:index]
  before_filter :script_user?, :except => [:index, :new, :create]
  
  # before_action :authenticate_client!

  def index
    @scripts = Script.order(created_at: :asc) 
  end
  
  def new
    @script = Script.new
  end
  
  def create
      @script = Script.new(script_params)
      if current_user
        @script.user_id = current_user.id
      else
        if current_client
          @script.client_id = current_client.id
        else
          redirect_to new_script_path, alert: "Contract could not be created: please sign in first."
        end
      end
      if @script.save
        redirect_to edit_script_path(@script), notice: 'Contract was successfully created.'
       else
        alert_string = ""
        @script.errors.full_messages.each do |msg|
          msg += ". "
          alert_string += msg 
        end
        redirect_to new_script_path, alert: alert_string
      end
  end
  

  def edit
    @script = Script.find(params[:id])
    
    case @script.category
      when "timelocked_address"
        if PublicKey.where(:script_id => @script.id, :name => "User").last
          @script.oracle_1_pub_key = PublicKey.where(:script_id => @script.id, :name => "User").last.compressed
        else
          @script.oracle_1_pub_key = ""
        end
        render :template => 'scripts/edit_tla'
        
      when "timelocked_2fa"
        if PublicKey.where(:script_id => @script.id, :name => "Service").last
          @script.oracle_1_pub_key = PublicKey.where(:script_id => @script.id, :name => "Service").last.compressed
        else
          @script.oracle_1_pub_key = ""
        end
        if PublicKey.where(:script_id => @script.id, :name => "User").last
          @script.oracle_2_pub_key = PublicKey.where(:script_id => @script.id, :name => "User").last.compressed
        else
          @script.oracle_2_pub_key = ""
        end
        render :template => 'scripts/edit_tl_2fa'
        
      when "contract_oracle"
        if PublicKey.where(:script_id => @script.id, :name => "User").last
          @script.oracle_1_pub_key = PublicKey.where(:script_id => @script.id, :name => "User").last.compressed
        else
          @script.oracle_1_pub_key = ""
        end
        if PublicKey.where(:script_id => @script.id, :name => "Service").last
          @script.oracle_2_pub_key = PublicKey.where(:script_id => @script.id, :name => "Service").last.compressed
        else
          @script.oracle_2_pub_key = ""
        end
        render :template => 'scripts/edit_contract_oracle'
        
      when "hashed_timelocked_contract"
        if PublicKey.where(:script_id => @script.id, :name => "Alice 1").last
          @script.alice_pub_key_1 = PublicKey.where(:script_id => @script.id, :name => "Alice 1").last.compressed
        else
          @script.alice_pub_key_1 = ""
        end
        if PublicKey.where(:script_id => @script.id, :name => "Alice 2").last
          @script.alice_pub_key_2 = PublicKey.where(:script_id => @script.id, :name => "Alice 2").last.compressed
        else
          @script.alice_pub_key_2 = ""
        end
        if PublicKey.where(:script_id => @script.id, :name => "Bob 1").last
          @script.bob_pub_key_1 = PublicKey.where(:script_id => @script.id, :name => "Bob 1").last.compressed
        else
          @script.bob_pub_key_1 = ""
        end
        if PublicKey.where(:script_id => @script.id, :name => "Bob 2").last
          @script.bob_pub_key_2 = PublicKey.where(:script_id => @script.id, :name => "Bob 2").last.compressed
        else
          @script.bob_pub_key_2 = ""
        end
        
        render :template => 'scripts/edit_htlc'
        
      when "tumblebit_puzzle"
        if PublicKey.where(:script_id => @script.id, :name => "Alice").last
          @script.alice_pub_key_1 = PublicKey.where(:script_id => @script.id, :name => "Alice").last.compressed
        else
          @script.alice_pub_key_1 = ""
        end
        if PublicKey.where(:script_id => @script.id, :name => "Tumbler").last
          @script.oracle_1_pub_key = PublicKey.where(:script_id => @script.id, :name => "Tumbler").last.compressed
        else
          @script.oracle_1_pub_key = ""
        end
        @script.contract = "a"
        
        render :template => 'scripts/edit_tumblebit_puzzle'
        
    end
  end
  

  def update
    @script = Script.find(params[:id])
    @script.update_attributes(script_params)
    @notice = ""
    case @script.category
        when "timelocked_address"
          if @script.oracle_1_pub_key
            @public_key = PublicKey.new(:script_id => @script.id, :compressed => @script.oracle_1_pub_key, :name => "User")
            @public_key.save
            @notice << @public_key.errors[:compressed].map { |s| "#{s}" }.join(' ')
          end

          if @notice.blank?
            render 'show_tla'
          else
            redirect_to @script, alert: @notice
          end

        when "timelocked_2fa"
          if @script.oracle_1_pub_key
            @public_key = PublicKey.new(:script_id => @script.id, :compressed => @script.oracle_1_pub_key, :name => "Service")
            @public_key.save
            @notice << @public_key.errors[:compressed].map { |s| "#{s}" }.join(' ')
          end
          if @script.oracle_2_pub_key
            @public_key = PublicKey.new(:script_id => @script.id, :compressed => @script.oracle_2_pub_key, :name => "User")
            @public_key.save
            @notice << @public_key.errors[:compressed].map { |s| "#{s}" }.join(' ')
          end

          if @notice.blank?
            render 'show_tl_2fa'
          else
            redirect_to @script, alert: @notice
          end

        when "contract_oracle"
          if @script.oracle_1_pub_key
            @public_key = PublicKey.new(:script_id => @script.id, :compressed => @script.oracle_1_pub_key, :name => "User")
            @public_key.save
            @notice << @public_key.errors[:compressed].map { |s| "#{s}" }.join(' ')
          end
          if @script.oracle_2_pub_key
            @public_key = PublicKey.new(:script_id => @script.id, :compressed => @script.oracle_2_pub_key, :name => "Service")
            @public_key.save
            @notice << @public_key.errors[:compressed].map { |s| "#{s}" }.join(' ')
          end

          if @notice.blank?
            render 'show_contract_oracle'
          else
            redirect_to @script, alert: @notice
          end
          
        when "hashed_timelocked_contract"
          
          if @script.alice_pub_key_1
            @public_key = PublicKey.new(:script_id => @script.id, :compressed => @script.alice_pub_key_1, :name => "Alice 1")
            @public_key.save
            @notice << @public_key.errors[:compressed].map { |s| "#{s}" }.join(' ')
          end
          if @script.alice_pub_key_2
            @public_key = PublicKey.new(:script_id => @script.id, :compressed => @script.alice_pub_key_2, :name => "Alice 2")
            @public_key.save
            @notice << @public_key.errors[:compressed].map { |s| "#{s}" }.join(' ')
          end
          if @script.bob_pub_key_1
            @public_key = PublicKey.new(:script_id => @script.id, :compressed => @script.bob_pub_key_1, :name => "Bob 1")
            @public_key.save
            @notice << @public_key.errors[:compressed].map { |s| "#{s}" }.join(' ')
          end
          if @script.bob_pub_key_2
            @public_key = PublicKey.new(:script_id => @script.id, :compressed => @script.bob_pub_key_2, :name => "Bob 2")
            @public_key.save
            @notice << @public_key.errors[:compressed].map { |s| "#{s}" }.join(' ')
          end
          @script.alice_pub_key_1 = PublicKey.where(:script_id => @script.id, :name => "Alice 1").last
          @script.alice_pub_key_2 = PublicKey.where(:script_id => @script.id, :name => "Alice 2").last
          @script.bob_pub_key_1 = PublicKey.where(:script_id => @script.id, :name => "Bob 1").last
          @script.bob_pub_key_2 = PublicKey.where(:script_id => @script.id, :name => "Bob 2").last

          if @notice.blank?
            render 'show_htlc'
          else
            redirect_to @script, alert: @notice
          end
          
        when "tumblebit_puzzle"
          
          if @script.alice_pub_key_1
            @public_key = PublicKey.new(:script_id => @script.id, :compressed => @script.alice_pub_key_1, :name => "Alice")
            @public_key.save
            @notice << @public_key.errors[:compressed].map { |s| "#{s}" }.join(' ')
          end
          if @script.oracle_1_pub_key
            @public_key = PublicKey.new(:script_id => @script.id, :compressed => @script.oracle_1_pub_key, :name => "Tumbler")
            @public_key.save
            @notice << @public_key.errors[:compressed].map { |s| "#{s}" }.join(' ')
          end
          
          @script.alice_pub_key_1 = PublicKey.where(:script_id => @script.id, :name => "Alice").last
          @script.oracle_1_pub_key = PublicKey.where(:script_id => @script.id, :name => "Tumbler").last
        
          if @notice.blank?
            render 'show_tumblebit_puzzle'
          else
            redirect_to @script, alert: @notice
          end
          
        else
          @public_keys = @script.public_keys
          render 'show'
    end

  end
  
  

  def show
    @script = Script.find(params[:id])
    @public_keys = @script.public_keys
    case @script.category
      when "timelocked_address"
        if PublicKey.where(:script_id => @script.id, :name => "User").last
          @script.oracle_1_pub_key = PublicKey.where(:script_id => @script.id, :name => "User").last.compressed
        else
          @script.oracle_1_pub_key = ""
        end
        render 'show_tla'
        
      when "timelocked_2fa"
        if PublicKey.where(:script_id => @script.id, :name => "Service").last
          @script.oracle_1_pub_key = PublicKey.where(:script_id => @script.id, :name => "Service").last.compressed
        else
          @script.oracle_1_pub_key = ""
        end
        if PublicKey.where(:script_id => @script.id, :name => "User").last
          @script.oracle_2_pub_key = PublicKey.where(:script_id => @script.id, :name => "User").last.compressed
        else
          @script.oracle_2_pub_key = ""
        end
        render 'show_tl_2fa'
        
      when "contract_oracle"
        if PublicKey.where(:script_id => @script.id, :name => "User").last
          @script.oracle_1_pub_key = PublicKey.where(:script_id => @script.id, :name => "User").last.compressed
        else
          @script.oracle_1_pub_key = ""
        end
        if PublicKey.where(:script_id => @script.id, :name => "Service").last
          @script.oracle_2_pub_key = PublicKey.where(:script_id => @script.id, :name => "Service").last.compressed
        else
          @script.oracle_2_pub_key = ""
        end
        render 'show_contract_oracle'
        
      when "hashed_timelocked_contract"
        @script.alice_pub_key_1 = PublicKey.where(:script_id => @script.id, :name => "Alice 1").last
        @script.alice_pub_key_2 = PublicKey.where(:script_id => @script.id, :name => "Alice 2").last
        @script.bob_pub_key_1 = PublicKey.where(:script_id => @script.id, :name => "Bob 1").last
        @script.bob_pub_key_2 = PublicKey.where(:script_id => @script.id, :name => "Bob 2").last
        render 'show_htlc'
        
      when "tumblebit_puzzle"
        @script.alice_pub_key_1 = PublicKey.where(:script_id => @script.id, :name => "Alice").last
        @script.oracle_1_pub_key = PublicKey.where(:script_id => @script.id, :name => "Tumbler").last
        render 'show_tumblebit_puzzle'

    end
    
  end
  
  
  def destroy
    @script = Script.find_by_id(params[:id])
    if @script.virgin?
      @script.public_keys.each do |public_key|
        public_key.destroy
      end
      @script.destroy
      redirect_to scripts_path, notice: 'Contract was successfully deleted.'
    else
      redirect_to @script, alert: 'Contract was funded, it cannot be deleted.'
    end
  end
  
  def create_spending_tx
    @script = Script.find(params[:id])
    
    case @script.category
      when "timelocked_address"
        @script.oracle_1_pub_key = PublicKey.where(:script_id => @script.id, :name => "User").last.compressed
        
      when "timelocked_2fa"
        @script.oracle_1_pub_key = PublicKey.where(:script_id => @script.id, :name => "Service").last.compressed
        @script.oracle_2_pub_key = PublicKey.where(:script_id => @script.id, :name => "User").last.compressed
      
      when "contract_oracle"
        @script.oracle_1_pub_key = PublicKey.where(:script_id => @script.id, :name => "User").last.compressed
        @script.oracle_2_pub_key = PublicKey.where(:script_id => @script.id, :name => "Service").last.compressed
          
      when "hashed_timelocked_contract"
        @script.secret = ""
        @script.alice_pub_key_1 = PublicKey.where(:script_id => @script.id, :name => "Alice 1").last.compressed
        @script.alice_pub_key_2 = PublicKey.where(:script_id => @script.id, :name => "Alice 2").last.compressed
        @script.bob_pub_key_1 = PublicKey.where(:script_id => @script.id, :name => "Bob 1").last.compressed
        @script.bob_pub_key_2 = PublicKey.where(:script_id => @script.id, :name => "Bob 2").last.compressed
        
      when "tumblebit_puzzle"
        @script.update(contract: "a")
        @script.alice_pub_key_1 = PublicKey.where(:script_id => @script.id, :name => "Alice").last.compressed
        @script.oracle_1_pub_key = PublicKey.where(:script_id => @script.id, :name => "Tumbler").last.compressed
        
    end
    
    if @script.funded?
      @script.first_unspent_tx
    else
      redirect_to @script, alert: 'Contract not funded or already spent: no UTXO available.'
    end
  end

  def sign_tx
    
    require 'btcruby/extensions'
    
    @notice = "Contract spending transaction was successfully signed."
    @script = Script.find(params[:id])
    @public_keys = @script.public_keys
    
    @script.confirmations = params[:script][:confirmations]
    @script.priv_key = params[:script][:priv_key]
    @script.oracle_1_priv_key = params[:script][:oracle_1_priv_key]
    @script.oracle_2_priv_key = params[:script][:oracle_2_priv_key]
    
    @script.alice_priv_key_1 = params[:script][:alice_priv_key_1]
    @script.alice_priv_key_2 = params[:script][:alice_priv_key_2]
    @script.bob_priv_key_1 = params[:script][:bob_priv_key_1]
    @script.bob_priv_key_2 = params[:script][:bob_priv_key_2]
    @script.secret = params[:script][:secret]
    @script.refund_address = params[:script][:refund_address]
    
    # ignore secret_ki parameters except secret_k1 for the demo, they are hardcoded to simplify the demo
    @script.secret_k1 = params[:script][:secret_k1] 
    @script.secret_k2 = params[:script][:secret_k2]
    @script.secret_k3 = params[:script][:secret_k3]
    @script.secret_k4 = params[:script][:secret_k4]
    @script.secret_k5 = params[:script][:secret_k5]
    @script.secret_k6 = params[:script][:secret_k6]
    @script.secret_k7 = params[:script][:secret_k7]
    @script.secret_k8 = params[:script][:secret_k8]
    @script.secret_k9 = params[:script][:secret_k9]
    @script.secret_k10 = params[:script][:secret_k10]
    @script.secret_k11 = params[:script][:secret_k11]
    @script.secret_k12 = params[:script][:secret_k12]
    @script.secret_k13 = params[:script][:secret_k13]
    @script.secret_k14 = params[:script][:secret_k14]
    @script.secret_k15 = params[:script][:secret_k15]
    
    @script.index = params[:script][:index]
    @script.tx_hash = params[:script][:tx_hash]
    @script.amount = params[:script][:amount]
    fee = 0.0001  # approx. 5 cts when 1 BTC = 500 EUR
    @previous_index = @script.index.to_i
    @previous_id = @script.tx_hash
    # @refund_address = BTC::Address.parse("16zQaNAg77jco2EDVSsU4bEAq5DgfZPZP4") # my electrum wallet
    
    begin  
      @refund_address = BTC::Address.parse(@script.refund_address)
    rescue Exception => era
      redirect_to @script, alert: "Invalid refund destination address."
      return
    end
    @script.update(refund_address: params[:script][:refund_address])

    @value = (@script.amount.to_f - fee) * BTC::COIN # @value is expressed in satoshis
    @funding_script = @script.funding_script
    
    case @script.category
      
      when "timelocked_address"
        
        if @script.expired?
          puts "We are after expiry: require user key only"
          # trying to spend 54 minutes after expiry returns "non-final"
          begin  
            @user_key = BTC::Key.new(wif:@script.oracle_1_priv_key)
          rescue Exception => e
            redirect_to @script, alert: "Invalid user private key."
            return
          end
          # Private keys associated with compressed public keys are 52 characters and start with a capital L or K on mainnet (c on testnet).
          
          tx = BTC::Transaction.new
          # tx.lock_time = 1473269401
          tx.lock_time = @script.expiry_date.to_i + 1 # time after expiry and before present (in the past)
          tx.add_input(BTC::TransactionInput.new( previous_id: @previous_id,
                                                  previous_index: @previous_index,
                                                  sequence: 0))
          tx.add_output(BTC::TransactionOutput.new(value: @value, script: @refund_address.script))
          hashtype = BTC::SIGHASH_ALL
          sighash = tx.signature_hash(input_index: 0,
                                      output_script: @funding_script,
                                      hash_type: hashtype)
          tx.inputs[0].signature_script = BTC::Script.new
          if e.blank?
            tx.inputs[0].signature_script << (@user_key.ecdsa_signature(sighash) + BTC::WireFormat.encode_uint8(hashtype))
          end
          tx.inputs[0].signature_script << @funding_script.data
        else
          @notice = "before expiry, no way to spend script, the network will return: Locktime requirement not satisfied"
          # trying to spend before expiry with user key only and a locktime in the past should return "Locktime requirement not satisfied".
          # this error message means that the network rejects the tx based on the expiry date set int the script even if the tx locktime is in the past.
          begin  
            @user_key = BTC::Key.new(wif:@script.oracle_1_priv_key)
          rescue Exception => e
            redirect_to @script, alert: "Invalid user private key."
            return
          end
          # Private keys associated with compressed public keys are 52 characters and start with a capital L or K on mainnet (c on testnet).
          tx = BTC::Transaction.new
          tx.lock_time = 1471199999 # some time in the past (2016-08-14)
          tx.add_input(BTC::TransactionInput.new( previous_id: @previous_id,
                                                  previous_index: @previous_index,
                                                  sequence: 0))
          tx.add_output(BTC::TransactionOutput.new(value: @value, script: @refund_address.script))
          
          hashtype = BTC::SIGHASH_ALL
          sighash = tx.signature_hash(input_index: 0,
                                      output_script: @funding_script,
                                      hash_type: hashtype)
          tx.inputs[0].signature_script = BTC::Script.new
          if e.blank?
            tx.inputs[0].signature_script << (@user_key.ecdsa_signature(sighash) + BTC::WireFormat.encode_uint8(hashtype))
          end
          tx.inputs[0].signature_script << @funding_script.data
        end
      
      when "timelocked_2fa"
        
        if @script.expired?
          puts "We are after expiry: 2FA expired, require user key only"
          # spending with both user key and service key is still possible.
          # trying to spend 31 minutes after expiry returns "non-final"
          # trying to spend 56 minutes after expiry works!
          begin  
            @user_key = BTC::Key.new(wif:@script.oracle_2_priv_key)
          rescue Exception => e
            redirect_to @script, alert: "Invalid user private key."
            return
          end
          # Private keys associated with compressed public keys are 52 characters and start with a capital L or K on mainnet (c on testnet).
          tx = BTC::Transaction.new
          # tx.lock_time = 1473269401
          tx.lock_time = @script.expiry_date.to_i + 1 # time after expiry and before present (in the past)
          tx.add_input(BTC::TransactionInput.new( previous_id: @previous_id,
                                                  previous_index: @previous_index,
                                                  sequence: 0))
          tx.add_output(BTC::TransactionOutput.new(value: @value, script: @refund_address.script))

          hashtype = BTC::SIGHASH_ALL
          sighash = tx.signature_hash(input_index: 0,
                                      output_script: @funding_script,
                                      hash_type: hashtype)
          tx.inputs[0].signature_script = BTC::Script.new
          if e.blank?
            tx.inputs[0].signature_script << (@user_key.ecdsa_signature(sighash) + BTC::WireFormat.encode_uint8(hashtype))
          end
          tx.inputs[0].signature_script << BTC::Script::OP_FALSE # force script execution into checking that expiry was before locktime, then locktime is checked to be in the past as well
          tx.inputs[0].signature_script << @funding_script.data
        else
          puts "2FA, before expiry, require both user key and service key"
          # trying to spend before expiry with user key only and a locktime in the past should return "Locktime requirement not satisfied".
          # this error message means that the network rejects the tx based on the expiry date set int the script even if the tx locktime is in the past.
          begin  
            @user_key = BTC::Key.new(wif:@script.oracle_2_priv_key)
          rescue Exception => e
            redirect_to @script, alert: "Invalid user private key."
            return
          end
          begin  
            @escrow_key = BTC::Key.new(wif:@script.oracle_1_priv_key)
          rescue Exception => e
            redirect_to @script, alert: "Invalid user private key."
            return
          end
          # Private keys associated with compressed public keys are 52 characters and start with a capital L or K on mainnet (c on testnet).
          tx = BTC::Transaction.new
          tx.lock_time = 1471199999 # some time in the past (2016-08-14)
          tx.add_input(BTC::TransactionInput.new( previous_id: @previous_id,
                                                  previous_index: @previous_index,
                                                  sequence: 0))
          tx.add_output(BTC::TransactionOutput.new(value: @value, script: @refund_address.script))
          
          hashtype = BTC::SIGHASH_ALL
          sighash = tx.signature_hash(input_index: 0,
                                      output_script: @funding_script,
                                      hash_type: hashtype)
          tx.inputs[0].signature_script = BTC::Script.new
          if e2.blank?
            puts "e2 blank"
            tx.inputs[0].signature_script << (@user_key.ecdsa_signature(sighash) + BTC::WireFormat.encode_uint8(hashtype))
          end
          if e1.blank?
            puts "e1 blank"
            tx.inputs[0].signature_script << (@escrow_key.ecdsa_signature(sighash) + BTC::WireFormat.encode_uint8(hashtype))
          end
          tx.inputs[0].signature_script << BTC::Script::OP_TRUE # force script execution into checking 2 signatures, ignoring expiry
          tx.inputs[0].signature_script << @funding_script.data
        end
        
      when "contract_oracle" # <hash> OP_DROP 2 <beneficiary pubkey> <oracle pubkey> CHECKMULTISIG
                            # <hash>: SHA256 of a json file like { "param_1":"value_1", "param_2":"value_2" }
                            # param_1 and 2 are described in the contract, value_1 and 2 come from external data sources
        begin  
          @user_key = BTC::Key.new(wif:@script.oracle_1_priv_key)
        rescue Exception => e1
          redirect_to @script, alert: "Invalid user private key."
          return
        end
        begin  
          @escrow_key = BTC::Key.new(wif:@script.oracle_2_priv_key)
        rescue Exception => e2
          redirect_to @script, alert: "Invalid user private key."
          return
        end
         # Private keys associated with compressed public keys are 52 characters and start with a capital L or K on mainnet (c on testnet).
        tx = BTC::Transaction.new
        tx.add_input(BTC::TransactionInput.new( previous_id: @previous_id,
                                                previous_index: @previous_index,
                                                sequence: 0))
        tx.add_output(BTC::TransactionOutput.new(value: @value, script: @refund_address.script))
        
        hashtype = BTC::SIGHASH_ALL
        sighash = tx.signature_hash(input_index: 0,
                                    output_script: @funding_script,
                                    hash_type: hashtype)
        tx.inputs[0].signature_script = BTC::Script.new
        tx.inputs[0].signature_script << BTC::Script::OP_FALSE
        if e1.blank?
          tx.inputs[0].signature_script << (@user_key.ecdsa_signature(sighash) + BTC::WireFormat.encode_uint8(hashtype))
        end
        if e2.blank?
          tx.inputs[0].signature_script << (@escrow_key.ecdsa_signature(sighash) + BTC::WireFormat.encode_uint8(hashtype))
        end

        tx.inputs[0].signature_script << @funding_script.data
      
      when "hashed_timelocked_contract" #   IF
                                      #   HASH160 <hash160(S)> EQUALVERIFY
                                      #   FALSE 2 <AlicePubkey1> <BobPubkey1>
                                      #   ELSE
                                      #   FALSE 2 <AlicePubkey2> <BobPubkey2>
                                      #   ENDIF
                                      #   2 CHECKMULTISIG
                                      
        tx = BTC::Transaction.new
        tx.add_input(BTC::TransactionInput.new( previous_id: @previous_id,
                                                previous_index: @previous_index,
                                                sequence: 0))
        tx.add_output(BTC::TransactionOutput.new(value: @value, script: @refund_address.script))
        hashtype = BTC::SIGHASH_ALL
        sighash = tx.signature_hash(input_index: 0,
                                    output_script: @funding_script,
                                    hash_type: hashtype)
        tx.inputs[0].signature_script = BTC::Script.new
        tx.inputs[0].signature_script << BTC::Script::OP_0
                                      
        if @script.secret == @script.contract
          puts "require Alice key 1 and Bob key 1, knowing S"
          begin  
            @alice_key_1 = BTC::Key.new(wif:@script.alice_priv_key_1)
          rescue Exception => ea1
            redirect_to @script, alert: "Invalid private key for Alice."
            return
          end
          begin  
            @bob_key_1 = BTC::Key.new(wif:@script.bob_priv_key_1)
          rescue Exception => eb1
            redirect_to @script, alert: "Invalid private key for Bob."
            return
          end
          
          if ea1.blank?
            tx.inputs[0].signature_script << (@alice_key_1.ecdsa_signature(sighash) + BTC::WireFormat.encode_uint8(hashtype))
          end
          if eb1.blank?
            tx.inputs[0].signature_script << (@bob_key_1.ecdsa_signature(sighash) + BTC::WireFormat.encode_uint8(hashtype))
          end
          tx.inputs[0].signature_script.append_pushdata(@script.contract)
          tx.inputs[0].signature_script << BTC::Script::OP_TRUE # force script execution into checking S and 2 signatures
          
        else
          puts "require only Alice key 2 and Bob key 2, ignoring S"
          
          begin  
            @alice_key_2 = BTC::Key.new(wif:@script.alice_priv_key_2)
          rescue Exception => ea2
            redirect_to @script, alert: "Invalid private key for Alice."
            return
          end
          begin  
            @bob_key_2 = BTC::Key.new(wif:@script.bob_priv_key_2)
          rescue Exception => eb2
            redirect_to @script, alert: "Invalid private key for Bob."
            return
          end
          
          if ea2.blank?
            tx.inputs[0].signature_script << (@alice_key_2.ecdsa_signature(sighash) + BTC::WireFormat.encode_uint8(hashtype))
          end
          if eb2.blank?
            tx.inputs[0].signature_script << (@bob_key_2.ecdsa_signature(sighash) + BTC::WireFormat.encode_uint8(hashtype))
          end
          tx.inputs[0].signature_script << BTC::Script::OP_FALSE # force script execution into checking other 2 signatures, ignoring S
        end
        
        tx.inputs[0].signature_script << @funding_script.data
        
      when "tumblebit_puzzle"
        
        @script.alice_pub_key_1 = PublicKey.where(:script_id => @script.id, :name => "Alice").last.compressed
        @script.oracle_1_pub_key = PublicKey.where(:script_id => @script.id, :name => "Tumbler").last.compressed
                                      
        unless @script.expired?
          puts "require Tumbler key, knowing puzzle solution"
          tx = BTC::Transaction.new
          # tx.lock_time = 1471199999 # some time in the past (2016-08-14)
          tx.add_input(BTC::TransactionInput.new( previous_id: @previous_id,
                                                  previous_index: @previous_index,
                                                  sequence: 0))
          tx.add_output(BTC::TransactionOutput.new(value: @value, script: @refund_address.script))
          hashtype = BTC::SIGHASH_ALL
          sighash = tx.signature_hash(input_index: 0,
                                      output_script: @funding_script,
                                      hash_type: hashtype)
          tx.inputs[0].signature_script = BTC::Script.new
          # tx.inputs[0].signature_script << BTC::Script::OP_0
          
          
          begin  
            @tumbler_key = BTC::Key.new(wif:@script.oracle_1_priv_key)
          rescue Exception => et
            redirect_to @script, alert: "Invalid private key for Tumbler."
            return
          end
          if et.blank?
            puts "Tumbler signature appended"
            tx.inputs[0].signature_script << (@tumbler_key.ecdsa_signature(sighash) + BTC::WireFormat.encode_uint8(hashtype))
          end
          k = Array["o", "n", "m", "l", "k", "j", "i", "h", "g", "f", "e", "d", "c", "b", "a"] # ignore secret_ki parameters for the demo.

          # for i in 0..14
          #  tx.inputs[0].signature_script.append_pushdata(k[14-i]) # h[1] = BTC.ripemd160(k[1]) where k[1] is a string
          #end
          
          for i in 0..14
            @script.update(contract: k[i])
            tx.inputs[0].signature_script.append_pushdata(@script.contract)
          end
          
          # tx.inputs[0].signature_script.append_pushdata(@script.contract)

          tx.inputs[0].signature_script << BTC::Script::OP_TRUE # force script execution into checking puzzle solution and Tumbler's signature
          
        else
          puts "after expiry, require only Alice key, ignoring puzzle solution."
          tx = BTC::Transaction.new
          tx.lock_time = @script.expiry_date.to_i + 1
          tx.add_input(BTC::TransactionInput.new( previous_id: @previous_id,
                                                  previous_index: @previous_index,
                                                  sequence: 0))
          tx.add_output(BTC::TransactionOutput.new(value: @value, script: @refund_address.script))
          hashtype = BTC::SIGHASH_ALL
          sighash = tx.signature_hash(input_index: 0,
                                      output_script: @funding_script,
                                      hash_type: hashtype)
          tx.inputs[0].signature_script = BTC::Script.new
          begin  
            @alice_key = BTC::Key.new(wif:@script.alice_priv_key_1)
          rescue Exception => ea
            redirect_to @script, alert: "Invalid private key for Alice."
            return
          end
          if ea.blank?
            puts "Alice signature appended"
            tx.inputs[0].signature_script << (@alice_key.ecdsa_signature(sighash) + BTC::WireFormat.encode_uint8(hashtype))
          end
          tx.inputs[0].signature_script << BTC::Script::OP_FALSE # force script execution into checking Alice's signature, ignoring puzzle solution
        end
        
        tx.inputs[0].signature_script << @funding_script.data

    end # of case statement
    @script.signed_tx = tx.to_s
    
    s = @notice
    if e
      s += e.message
    end
    unless s == "Contract spending transaction was successfully signed."
      redirect_to @script, alert: s
    end
  end
  
  
  def broadcast
    @script = Script.find(params[:id])
    @script.signed_tx = params[:script][:signed_tx]

    # $PUSH_TX_URL = "https://api.blockcypher.com/v1/btc/main/txs/push"
    uri = URI.parse($PUSH_TX_URL)  # param is "tx"

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new(uri.path, {'Content-Type' =>'application/json'})
    data = {"tx": @script.signed_tx}
    request.body = data.to_json

    response = http.request(request)  # broadcast transaction using $PUSH_TX_URL
    
    post_response = JSON.parse(response.body)
    if post_response["error"]
      puts "Tx broadcast failed: #{post_response["error"]}"
      redirect_to @script, alert: "Tx broadcast failed. "+"#{post_response["error"]}"
    else
      puts "Tx was broadcast successfully with Tx ID: #{post_response['tx']['hash']}"
      redirect_to @script, notice: "Tx was broadcast successfully with Tx ID: #{post_response['tx']['hash']}"
    end
  end


  private
 
     def script_params
       params.require(:script).permit(:signed_tx, :refund_address, :alice_pub_key_1, :alice_pub_key_2, :bob_pub_key_1, :bob_pub_key_2,:oracle_1_pub_key,:oracle_2_pub_key, :contract, :title, :text, :expiry_date, :category, :user_id, public_keys_attributes: [:name, :compressed, :script_id])
     end

end