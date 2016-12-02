class SessionsController < ApplicationController
  
  def new
    unless client_signed_in?
      redirect_to '/auth/twitter'
    else
      redirect_to root_url, :alert => 'You need to log out out before you sign in as admin.'
    end
  end

  def create
      auth = request.env["omniauth.auth"]
      user = User.where(:provider => auth['provider'],
                        :uid => auth['uid'].to_s).first || User.create_with_omniauth(auth)
      reset_session
      session[:user_id] = user.id
      if user.email.blank?
        redirect_to edit_user_path(user), :info => "Thanks for signing up! Please enter your email address to complete your profile."
      else
        redirect_to root_url, :notice => 'Signed in!'
      end

    end

  def destroy
    reset_session
    redirect_to root_url, :notice => 'Signed out!'
  end

  def failure
    redirect_to root_url, :alert => "Authentication error: #{params[:message].humanize}"
  end

end