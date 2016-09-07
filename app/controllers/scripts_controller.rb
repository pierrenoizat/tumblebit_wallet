class ScriptsController < ApplicationController


  def index
    @scripts = Script.all
  end
  
  def new
    @script = Script.new
  end
  
  def create
      @script = Script.new(script_params)

      if @script.save
        redirect_to @script, notice: 'Bitcoin script was successfully created.'
       else
         render action: 'new'
      end
  end
  

  def edit
    @script = Script.find(params[:id])
  end

  def update
    @script = Script.find(params[:id])
    if @script.update_attributes(script_params)
      redirect_to @script, notice: 'Script was successfully updated.'
    else
      render :edit
    end
  end
  
  

  def show
    @script = Script.find(params[:id])
    @public_keys = @script.public_keys
  end
  
  
  
  def destroy
    @script = Script.find_by_id(params[:id])
    @script.destroy
      
    redirect_to scripts_path, notice: 'Script was successfully deleted.'
  end
  
  def display 
    @script = Script.find_by_id(params[:id])
  end
  
  def create_spending_tx
    @script = Script.find(params[:id])
    @public_keys = @script.public_keys
    unless @script.first_unspent_tx
      redirect_to @script, notice: 'Script not funded: no UTXO available.'
    end
  end

  def create_signed_transaction
    @script = Script.find(params[:id])
    @public_keys = @script.public_keys
    @script.priv_key = params[:script][:priv_key]
    @script.service_priv_key = params[:script][:service_priv_key]
    @script.index = params[:script][:index]
    @script.tx_hash = params[:script][:tx_hash]
    @script.amount = params[:script][:amount]
    fee = 0.0001  # approx. 5 cts when 1 BTC = 500 EUR
    @previous_index = @script.index.to_i
    @previous_id = @script.tx_hash
    @refund_address = BTC::Address.parse("16zQaNAg77jco2EDVSsU4bEAq5DgfZPZP4") # my electrum wallet
    @value = (@script.amount.to_f - fee) * BTC::COIN # @value is expressed in satoshis
    
    if Time.now.to_i > @script.expiry_date.to_i
      # we are after expiry: 2FA expired, require user key only
      puts "We are after expiry: 2FA expired, require user key only"
      
      @funding_script = BTC::Script.new
      @escrow_key=BTC::Key.new(public_key:BTC.from_hex(@script.public_keys.first.compressed))
      @user_key = BTC::Key.new(wif:@script.priv_key)
      @expire_at = Time.at(@script.expiry_date.to_time.to_i)
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
      puts BTC::ScriptHashAddress.new(redeem_script:@funding_script, network:BTC::Network.default)
      puts @funding_script
      puts @user_key.to_wif
      puts @previous_id
      tx = BTC::Transaction.new
      tx.lock_time = 1473269401
      # tx.lock_time = 1473241000
      # tx.lock_time = @script.expiry_date.to_i + 1 # time after expiry and before present (in the past)
      tx.add_input(BTC::TransactionInput.new( previous_id: @previous_id,
                                              previous_index: @previous_index,
                                              sequence: 0))
      tx.add_output(BTC::TransactionOutput.new(value: @value, script: @refund_address.script))
      hashtype = BTC::SIGHASH_ALL
      sighash = tx.signature_hash(input_index: 0,
                                  output_script: @funding_script,
                                  hash_type: hashtype)
      tx.inputs[0].signature_script = BTC::Script.new
      tx.inputs[0].signature_script << (@user_key.ecdsa_signature(sighash) + BTC::WireFormat.encode_uint8(hashtype))
      tx.inputs[0].signature_script << BTC::Script::OP_FALSE # force script execution into checking that expiry was before locktime, then locktime is checked to be in the past as well
      tx.inputs[0].signature_script << @funding_script.data
    else
      # 2FA, before expiry, require both user key and service key
      puts "2FA, before expiry, require both user key and service key"
      @user_key = BTC::Key.new(wif:@script.priv_key)
      @escrow_key = BTC::Key.new(wif:@script.service_priv_key)
      @funding_script = BTC::Script.new
      @expire_at = Time.at(@script.expiry_date.to_time.to_i)
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
      tx.inputs[0].signature_script << (@user_key.ecdsa_signature(sighash) + BTC::WireFormat.encode_uint8(hashtype))
      tx.inputs[0].signature_script << (@escrow_key.ecdsa_signature(sighash) + BTC::WireFormat.encode_uint8(hashtype))
      tx.inputs[0].signature_script << BTC::Script::OP_TRUE # force script execution into checking 2 signatures, ignoring expiry
      tx.inputs[0].signature_script << @funding_script.data
    end
    
    puts tx.to_s
    render :show
  end


  private
 
     def script_params
       params.require(:script).permit(:title, :text, :expiry_date, :category, public_keys_attributes: [:name, :compressed, :script_id])
     end

end