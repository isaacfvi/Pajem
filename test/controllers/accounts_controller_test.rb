require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @alice = User.create!(name: "Alice", email: "alice@test.com", password: "password123456")
    login_as(@alice)
  end

  # ─── GET /conta ───────────────────────────────────────────────────────

  test "GET /conta retorna 200 para usuário autenticado" do
    get conta_path
    assert_response :success
    assert_match @alice.email, response.body
  end

  test "GET /conta redireciona para login sem autenticação" do
    delete logout_path
    get conta_path
    assert_redirected_to login_path
  end

  # ─── PATCH /conta (update senha) ─────────────────────────────────────

  test "PATCH /conta altera senha com credenciais corretas" do
    patch conta_path, params: {
      current_password: "password123456",
      new_password: "novaSenha999",
      new_password_confirmation: "novaSenha999"
    }
    assert_redirected_to conta_path
    assert @alice.reload.authenticate("novaSenha999")
  end

  test "PATCH /conta falha com senha atual incorreta" do
    patch conta_path, params: {
      current_password: "errada",
      new_password: "novaSenha999",
      new_password_confirmation: "novaSenha999"
    }
    assert_response :unprocessable_entity
    assert_nil @alice.reload.authenticate("novaSenha999")
  end

  test "PATCH /conta falha quando confirmação não confere" do
    patch conta_path, params: {
      current_password: "password123456",
      new_password: "novaSenha999",
      new_password_confirmation: "diferente999"
    }
    assert_response :unprocessable_entity
    assert @alice.reload.authenticate("password123456")
  end

  # ─── DELETE /conta (deactivate) ───────────────────────────────────────

  test "DELETE /conta deactivate preenche deleted_at" do
    delete conta_path, params: { action_type: "deactivate" }
    assert @alice.reload.discarded?
  end

  test "DELETE /conta deactivate encerra sessão" do
    delete conta_path, params: { action_type: "deactivate" }
    get conta_path
    assert_redirected_to login_path
  end

  test "DELETE /conta deactivate envia e-mail de reativação" do
    assert_enqueued_emails 1 do
      delete conta_path, params: { action_type: "deactivate" }
    end
  end

  test "DELETE /conta deactivate redireciona com notice" do
    delete conta_path, params: { action_type: "deactivate" }
    assert_redirected_to login_path
    assert_match "desativada", flash[:notice]
  end

  # ─── DELETE /conta (hard_delete) ─────────────────────────────────────

  test "DELETE /conta hard_delete destrói o usuário" do
    assert_difference "User.unscoped.count", -1 do
      delete conta_path, params: { action_type: "hard_delete" }
    end
  end

  test "DELETE /conta hard_delete encerra sessão antes de destruir" do
    delete conta_path, params: { action_type: "hard_delete" }
    get root_path
    assert_redirected_to login_path
  end

  test "DELETE /conta hard_delete redireciona com notice" do
    delete conta_path, params: { action_type: "hard_delete" }
    assert_redirected_to login_path
    assert_match "excluídos permanentemente", flash[:notice]
  end

  # ─── GET /conta/reativar/:token ───────────────────────────────────────

  test "GET /conta/reativar/:token válido reativa conta e inicia sessão" do
    @alice.update!(
      deleted_at: Time.current,
      reset_password_token: "tok123",
      reset_password_sent_at: 1.hour.ago
    )
    get reactivate_conta_path(token: "tok123")
    assert_redirected_to root_path
    assert_match "reativada", flash[:notice]
    assert_nil @alice.reload.deleted_at
  end

  test "GET /conta/reativar/:token expirado redireciona com alert" do
    @alice.update!(
      deleted_at: Time.current,
      reset_password_token: "tok_old",
      reset_password_sent_at: 49.hours.ago
    )
    get reactivate_conta_path(token: "tok_old")
    assert_redirected_to login_path
    assert_match "expirado", flash[:alert]
  end

  test "GET /conta/reativar/:token inválido redireciona com alert" do
    get reactivate_conta_path(token: "nao_existe")
    assert_redirected_to login_path
    assert_match "inválido", flash[:alert]
  end

  # ─── GET /conta/reativar/reenviar ────────────────────────────────────

  test "GET /conta/reativar/reenviar acessível sem autenticação" do
    delete logout_path
    get reactivation_form_conta_path
    assert_response :success
  end

  # ─── POST /conta/reativar/reenviar ───────────────────────────────────

  test "POST /conta/reativar/reenviar envia e-mail para conta desativada" do
    @alice.update!(deleted_at: Time.current)
    assert_enqueued_emails 1 do
      post resend_reactivation_conta_path, params: { email: @alice.email }
    end
  end

  test "POST /conta/reativar/reenviar e-mail inexistente não envia e-mail" do
    assert_enqueued_emails 0 do
      post resend_reactivation_conta_path, params: { email: "nao@existe.com" }
    end
  end

  test "POST /conta/reativar/reenviar sempre redireciona com mensagem genérica" do
    post resend_reactivation_conta_path, params: { email: "qualquer@email.com" }
    assert_redirected_to login_path
    assert_match "Se houver", flash[:notice]
  end

  private

  def login_as(user)
    delete logout_path
    post login_path, params: { email: user.email, password: "password123456" }
  end
end
