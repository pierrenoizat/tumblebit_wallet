class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  helper_method :current_user
  helper_method :user_signed_in?
  helper_method :correct_user?
  helper_method :user_admin?
  helper_method :script_user?

  private
  
    def current_user
      begin
        @current_user ||= User.find(session[:user_id]) if session[:user_id]
      rescue Exception => e
        nil
      end
    end

    def user_signed_in?
      return true if current_user
    end
    
    def user_admin?
      if current_user
        # current_user.uid == "418681302"
        current_user.uid == Figaro.env.btcscript_admin_uid.to_s
        # return User.find(session[:user_id]).uid == ENV["BTCSCRIPT_ADMIN_UID"]
      end
    end

    def correct_user?
      @user = User.find(params[:id])
      unless current_user == @user
        redirect_to root_url, :alert => "Access denied."
      end
    end
    
    def script_user?
      @script = Script.find(params[:id])
      unless current_user
        if current_client and @script.client_id
          @client = Client.find(@script.client_id)
          unless current_client == @client
          redirect_to scripts_url, :alert => "Access denied: this contract belongs to another user."
          end
        else
          redirect_to scripts_url, :alert => "Access denied: this contract belongs to another user."
        end
      end
      
      if current_user and @script.user_id
        @user = User.find(@script.user_id)
        unless current_user == @user
        redirect_to scripts_url, :alert => "Access denied: this contract belongs to another user."
        end
      end
    end

    def authenticate_user!
      if !current_user
        if !current_client
          redirect_to root_url, :alert => 'You need to sign in or sign up for access to this page.'
        end
      end
    end
    

end
