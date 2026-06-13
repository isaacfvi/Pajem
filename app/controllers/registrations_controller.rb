class RegistrationsController < ApplicationController
  skip_before_action :require_login
  before_action :require_no_login

  def new
    @user = User.new
  end

  def create
    @user = User.new(registration_params)
    if @user.save
      session[:user_id] = @user.id
      redirect_to root_path, notice: "Conta criada com sucesso! Bem-vindo ao Pajem."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def registration_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation)
  end
end
