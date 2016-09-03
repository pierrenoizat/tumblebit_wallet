class PublicKeysController < ApplicationController

  def index
    @public_keys = PublicKey.all.order('created_at DESC')
  end
  
  def edit
    @public_key = PublicKey.find(params[:id])
  end

  def update
    @public_key = PublicKey.find(params[:id])
    if @public_key.update_attributes(secure_params)
      redirect_to @public_key
    else
      render :edit
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

      if @public_key.save
        @script = Script.find(@public_key.script_id)
        redirect_to @script, notice: 'Public key was successfully recorded.'
       else
         render action: 'new'
      end
  end
  
  def destroy
    @public_key = PublicKey.find(params[:id])
    @public_key.destroy
    render :nothing
  end

  private

  def secure_params
    params.require(:public_key).permit(:name, :compressed, :script_id)
  end

end