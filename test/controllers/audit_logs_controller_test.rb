require "test_helper"

class AuditLogsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @alice = User.create!(name: "Alice", email: "alice@test.com", password: "password123456")
    @bob   = User.create!(name: "Bob",   email: "bob@test.com",   password: "password123456")

    @list     = @alice.lists.create!(title: "Compras")
    @item     = @list.items.create!(title: "Miojo", user: @alice)
    @bob_list = @bob.lists.create!(title: "Lista do Bob")

    @log_created   = AuditLog.record(user: @alice, action: "created",   auditable: @list,     origin: "manual")
    @log_completed = AuditLog.record(user: @alice, action: "completed", auditable: @item,     origin: "assistant")
    @log_bob       = AuditLog.record(user: @bob,   action: "created",   auditable: @bob_list, origin: "manual")

    @log_completed.update_columns(created_at: 30.days.ago)

    login_as(@alice)
  end

  # ─── GET /historico ─────────────────────────────────────────────────

  test "GET /historico exibe eventos do usuário" do
    get audit_logs_path
    assert_response :success
    assert_match "Compras", response.body
  end

  test "GET /historico não exibe eventos de outros usuários" do
    get audit_logs_path
    assert_no_match "Lista do Bob", response.body
  end

  test "GET /historico requer autenticação" do
    delete logout_path
    get audit_logs_path
    assert_redirected_to login_path
  end

  # ─── Filtro por action ───────────────────────────────────────────────

  test "GET /historico?action=created retorna apenas criados" do
    get audit_logs_path, params: { action: "created" }
    assert_response :success
    assert_match "criado", response.body
    assert_no_match "concluído", response.body
  end

  test "GET /historico?action=completed retorna apenas concluídos" do
    get audit_logs_path, params: { action: "completed" }
    assert_response :success
    assert_match "concluído", response.body
    assert_no_match "criado", response.body
  end

  # ─── Filtro por origin ───────────────────────────────────────────────

  test "GET /historico?origin=manual retorna apenas manuais" do
    get audit_logs_path, params: { origin: "manual" }
    assert_response :success
    assert_match "audit-entry__origin--manual", response.body
    assert_no_match "audit-entry__origin--assistant", response.body
  end

  test "GET /historico?origin=assistant retorna apenas do Pajem" do
    get audit_logs_path, params: { origin: "assistant" }
    assert_response :success
    assert_match "audit-entry__origin--assistant", response.body
    assert_no_match "audit-entry__origin--manual", response.body
  end

  # ─── Filtro por data ─────────────────────────────────────────────────

  test "GET /historico?date_from respeita limite inferior" do
    get audit_logs_path, params: { date_from: Date.today.to_s }
    assert_response :success
    assert_match "criado", response.body
    assert_no_match "concluído", response.body
  end

  test "GET /historico?date_to respeita limite superior" do
    get audit_logs_path, params: { date_to: 31.days.ago.to_date.to_s }
    assert_response :success
    assert_no_match "criado", response.body
  end

  # ─── Filtros combinados ──────────────────────────────────────────────

  test "GET /historico combina filtro action + origin" do
    get audit_logs_path, params: { action: "completed", origin: "assistant" }
    assert_response :success
    assert_match "concluído", response.body
    assert_no_match "criado", response.body
  end

  # ─── Estado vazio ────────────────────────────────────────────────────

  test "GET /historico exibe mensagem quando não há resultados" do
    get audit_logs_path, params: { action: "deleted" }
    assert_response :success
    assert_match "Nenhum evento encontrado", response.body
  end

  private

  def login_as(user)
    delete logout_path
    post login_path, params: { email: user.email, password: "password123456" }
  end
end
