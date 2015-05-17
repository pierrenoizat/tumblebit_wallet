class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  
  include ActionView::Helpers::AssetTagHelper
  include ActionView::Helpers::NumberHelper
  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::DateHelper

  helper_method :truncate_node_hash
  helper_method :current_user
  helper_method :user_signed_in?
  helper_method :correct_user?
  
  def truncate_node_hash(string)

    if string and string.size >25
      end_string = string[-12,12]
      truncated_string = truncate(string, length: 22, omission: '.......') + end_string
    else
      if string 
        truncated_string = string
      else
        truncated_string = ''
      end
    end

  end # of helper method

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

    def correct_user?
      @user = User.find(params[:id])
      unless current_user == @user
        redirect_to root_url, :alert => "Access denied."
      end
    end

    def authenticate_user!
      if !current_user
        redirect_to root_url, :alert => 'You need to sign in for access to this page.'
      end
    end
    
    def configure_permitted_parameters
        devise_parameter_sanitizer.for(:tree) << :avatar
      end

end
