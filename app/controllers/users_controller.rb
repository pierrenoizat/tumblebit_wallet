class UsersController < ApplicationController
  before_filter :authenticate_user!  # Users are whitelisted admins
  before_filter :correct_user?, :except => [:index, :new, :create]

  def index
    @users = User.all
  end

  def edit
    @user = User.find(params[:id])
  end

  def update
    @user = User.find(params[:id])
    if @user.update_attributes(secure_params)
      redirect_to @user
    else
      render :edit
    end
  end

  def show
    @user = User.find(params[:id])
  end

  private

  def secure_params
    params.require(:user).permit(:email, scripts_attributes: [:user_id])
  end

end