class AccountsController < ApplicationController
  skip_before_action :require_login, only: [ :reactivation_form, :resend_reactivation, :reactivate ]

  def show; end

  def update
    unless current_user.authenticate(params[:current_password])
      flash.now[:alert] = "Senha atual incorreta."
      return render :show, status: :unprocessable_entity
    end

    if current_user.update(password: params[:new_password], password_confirmation: params[:new_password_confirmation])
      redirect_to conta_path, notice: "Senha alterada com sucesso."
    else
      flash.now[:alert] = current_user.errors.full_messages.to_sentence
      render :show, status: :unprocessable_entity
    end
  end

  def destroy
    if params[:action_type] == "hard_delete"
      session.delete(:user_id)
      current_user.destroy
      redirect_to login_path, notice: "Seus dados foram excluídos permanentemente."
    else
      current_user.update!(deleted_at: Time.current, **reactivation_token_attrs)
      UserMailer.account_reactivation(current_user).deliver_later
      session.delete(:user_id)
      redirect_to login_path, notice: "Sua conta foi desativada. Você pode reativá-la pelo link enviado ao seu e-mail."
    end
  end

  def reactivate
    user = User.unscoped.find_by(reset_password_token: params[:token])

    if user.nil? || user.reset_password_sent_at < 48.hours.ago
      return redirect_to login_path, alert: "Link de reativação inválido ou expirado. Solicite um novo."
    end

    user.update!(deleted_at: nil, reset_password_token: nil, reset_password_sent_at: nil)
    session[:user_id] = user.id
    redirect_to root_path, notice: "Conta reativada com sucesso!"
  end

  def reactivation_form; end

  def resend_reactivation
    user = User.unscoped.find_by(email: params[:email].to_s.downcase.strip, deleted_at: ..Time.current)

    if user
      user.update!(reactivation_token_attrs)
      UserMailer.account_reactivation(user).deliver_later
    end

    redirect_to login_path, notice: "Se houver uma conta desativada associada a este e-mail, você receberá as instruções em breve."
  end

  private

  def reactivation_token_attrs
    { reset_password_token: SecureRandom.urlsafe_base64(32), reset_password_sent_at: Time.current }
  end
end
