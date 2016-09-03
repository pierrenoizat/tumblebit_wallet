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
      redirect_to @script
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



  private
 
     def script_params
       params.require(:script).permit(:title, :text, :expiry_date, public_keys_attributes: [:name, :compressed, :script_id])
     end

end