class PublicKeysController < ApplicationController

  def index
    @public_keys = PublicKey.all.order('created_at DESC')
  end
  
  def edit
    @public_key = PublicKey.find(params[:id])
  end

  def update
    @public_key = PublicKey.find(params[:id])
    @script = Script.find(@public_key.script_id)
    
    if @public_key.update_attributes(secure_params)
      redirect_to @script, notice: 'Public key was successfully recorded.'
    else
      redirect_to @script, alert: "Compressed Public Key #{@public_key.errors[:compressed].map { |s| "#{s}" }.join(' ')}"
    end
  end

  def show
    @public_key = PublicKey.find(params[:id])
    
    @script = Script.find(@public_key.script_id)
  end
  
  def new
    @public_key = PublicKey.new
  end
  
  def create
      @public_key = PublicKey.new(secure_params)
      @script = Script.find(@public_key.script_id)
      
      if @public_key.save
        redirect_to @script, notice: 'Public key was successfully recorded.'
       else
        redirect_to @script, alert: "Compressed Public Key #{@public_key.errors[:compressed].map { |s| "#{s}" }.join(' ')}"
      end
  end
  
  def destroy
    @public_key = PublicKey.find(params[:id])
    @script = Script.find(@public_key.script_id)
    @public_key.destroy
    redirect_to edit_script_path(@script), notice: 'Public key was successfully deleted.' 
  end

  private

  def secure_params
    params.require(:public_key).permit(:name, :compressed, :script_id)
  end

end