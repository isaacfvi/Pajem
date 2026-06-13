require "test_helper"

class PasswordResetsControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  def setup
    @user = User.create!(name: "Alice", email: "alice@example.com", password: "password123456")
  end

  test "GET /password/forgot renderiza o formulário" do
    get forgot_password_path
    assert_response :success
  end

  test "POST /password/forgot com e-mail conhecido envia mailer e redireciona" do
    assert_enqueued_emails 1 do
      post "/password/forgot", params: { email: "alice@example.com" }
    end
    assert_redirected_to login_path
    @user.reload
    assert_not_nil @user.reset_password_token
    assert_not_nil @user.reset_password_sent_at
  end

  test "POST /password/forgot com e-mail desconhecido redireciona sem revelar" do
    assert_no_enqueued_emails do
      post "/password/forgot", params: { email: "naoexiste@example.com" }
    end
    assert_redirected_to login_path
  end

  test "GET /password/reset com token válido renderiza o formulário" do
    @user.update_columns(reset_password_token: "tokenvalido123", reset_password_sent_at: Time.current)
    get reset_password_path, params: { token: "tokenvalido123" }
    assert_response :success
  end

  test "GET /password/reset com token expirado redireciona" do
    @user.update_columns(reset_password_token: "tokenexpirado", reset_password_sent_at: 3.hours.ago)
    get reset_password_path, params: { token: "tokenexpirado" }
    assert_redirected_to forgot_password_path
  end

  test "GET /password/reset com token inválido redireciona" do
    get reset_password_path, params: { token: "tokeninvalido" }
    assert_redirected_to forgot_password_path
  end

  test "PATCH /password/reset com token válido atualiza a senha" do
    @user.update_columns(reset_password_token: "tokenupdate", reset_password_sent_at: Time.current)
    patch "/password/reset", params: {
      token: "tokenupdate",
      user: { password: "novasenhasegura", password_confirmation: "novasenhasegura" }
    }
    assert_redirected_to login_path
    @user.reload
    assert_nil @user.reset_password_token
    assert @user.authenticate("novasenhasegura")
  end

  test "PATCH /password/reset com senha inválida re-renderiza com erro" do
    @user.update_columns(reset_password_token: "tokenshort", reset_password_sent_at: Time.current)
    patch "/password/reset", params: {
      token: "tokenshort",
      user: { password: "curta", password_confirmation: "curta" }
    }
    assert_response :unprocessable_entity
  end

  test "PATCH /password/reset com token expirado redireciona" do
    @user.update_columns(reset_password_token: "tokenexpupdate", reset_password_sent_at: 3.hours.ago)
    patch "/password/reset", params: {
      token: "tokenexpupdate",
      user: { password: "novasenhasegura", password_confirmation: "novasenhasegura" }
    }
    assert_redirected_to forgot_password_path
  end
end
