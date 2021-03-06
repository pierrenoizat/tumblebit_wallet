class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  include ActionView::Helpers::TextHelper
  
  include SessionsHelper   
    # before_filter :set_cache_headers  
    rescue_from ActionController::InvalidAuthenticityToken do |exception|  
      flash[:danger] = "If this keeps happening please contact me. Thank you!"  
      redirect_to root_url  
    end  

  helper_method :current_user
  helper_method :user_signed_in?
  helper_method :correct_user?
  helper_method :user_admin?
  helper_method :script_user?
  helper_method :valid_pubkey?
  helper_method :truncated
  
  
  def truncated(string)
    if string and string.size >25
      end_string = string[-4,4] # keeps only last 4 caracters
      truncated_string = truncate(string, length: 8, omission: '...') + end_string # keeps only first 5 caracters, with 3 dots (total length 8)
    else
      if string 
        truncated_string = string
      else
        truncated_string = ''
      end
    end
  end
  

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
        current_user.uid == Figaro.env.tumbler_admin_uid.to_s
      end
    end

    def correct_user?
      @user = User.find_by_id(params[:id])
      unless (current_user and current_user == @user)
        redirect_to root_url, :alert => "Access denied."
      end
    end
    
    def correct_client?
      unless user_admin?
        @client = Client.find_by_id(params[:id])
        unless (current_client and current_client == @client)
          redirect_to root_url, :alert => "Access denied."
        end
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
          redirect_to root_url, :alert => 'You need to log in or sign up for access to this page.'
        end
      end
    end
    
    def bitcoin_elliptic_curve
      ::OpenSSL::PKey::EC.new("secp256k1")
    end
        
    def valid_pubkey?(pubkey)
      ::OpenSSL::PKey::EC::Point.from_hex(bitcoin_elliptic_curve.group, pubkey)
      true
      rescue OpenSSL::PKey::EC::Point::Error,OpenSSL::BNError
      false
    end

    

end
