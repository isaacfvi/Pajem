class UserMailer < ApplicationMailer
  def password_reset(user)
    @user = user
    mail(to: @user.email, subject: "Recuperação de senha — Pajem")
  end

  def account_reactivation(user)
    @user = user
    mail(to: @user.email, subject: "Reativação de conta — Pajem")
  end
end
