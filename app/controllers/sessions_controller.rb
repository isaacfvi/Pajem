class SessionsController < ApplicationController
  skip_before_action :require_login
  before_action :require_no_login, only: %i[ new create ]
  before_action :require_login,    only: :destroy

  def new
  end

  def create
    user = User.kept.find_by(email: params[:email].to_s.downcase.strip)
    if user&.authenticate(params[:password])
      session[:user_id] = user.id
      redirect_to session.delete(:return_to) || root_path, notice: "Bem-vindo de volta, #{user.name}!"
    else
      flash.now[:alert] = "E-mail ou senha inválidos."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session
    redirect_to login_path, notice: "Você saiu da sua conta."
  end
end
