class PasswordResetsController < ApplicationController
  skip_before_action :require_login

  def new
  end

  def create
    user = User.kept.find_by(email: params[:email].to_s.downcase.strip)
    if user
      user.update_columns(
        reset_password_token: SecureRandom.urlsafe_base64(32),
        reset_password_sent_at: Time.current
      )
      UserMailer.password_reset(user).deliver_later
    end
    redirect_to login_path, notice: "Se o e-mail existir, você receberá as instruções em breve."
  end

  def edit
    @user = find_user_by_token
    redirect_to forgot_password_path, alert: "Link inválido ou expirado. Solicite um novo." unless @user
  end

  def update
    @user = find_user_by_token
    unless @user
      redirect_to forgot_password_path, alert: "Link inválido ou expirado. Solicite um novo."
      return
    end

    if @user.update(password_params)
      @user.update_columns(reset_password_token: nil, reset_password_sent_at: nil)
      redirect_to login_path, notice: "Senha redefinida com sucesso. Faça o login."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def find_user_by_token
    token = params[:token].to_s
    return nil if token.blank?

    user = User.kept.find_by(reset_password_token: token)
    return nil unless user
    return nil if user.reset_password_sent_at < 2.hours.ago

    user
  end

  def password_params
    params.require(:user).permit(:password, :password_confirmation)
  end
end
