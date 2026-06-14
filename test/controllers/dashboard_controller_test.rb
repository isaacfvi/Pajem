require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  def setup
    @alice = User.create!(name: "Alice", email: "alice@test.com", password: "password123456")
    @bob   = User.create!(name: "Bob",   email: "bob@test.com",   password: "password123456")
    @ctx   = @alice.contexts.create!(name: "Trabalho")
    @list  = @alice.lists.create!(title: "Tarefas", context: @ctx)
    @item  = @list.items.create!(title: "Estudar", user: @alice)
    login_as(@alice)
  end

  # ─── Acesso ───────────────────────────────────────────────────────────

  test "GET / retorna 200 para usuário autenticado" do
    get root_path
    assert_response :success
  end

  test "GET / redireciona para login sem autenticação" do
    delete logout_path
    get root_path
    assert_redirected_to login_path
  end

  # ─── Contadores ───────────────────────────────────────────────────────

  test "GET / não exibe dados de outro usuário nos contadores" do
    bob_list = @bob.lists.create!(title: "Lista Bob")
    bob_list.items.create!(title: "Item Bob", user: @bob)
    get root_path
    assert_equal 1, assigns(:lists_count)
    assert_equal 1, assigns(:pending_count)
  end

  test "GET / conta itens vencidos corretamente" do
    @item.update!(due_date: 2.days.ago)
    get root_path
    assert_equal 1, assigns(:overdue_count)
  end

  test "GET / não conta itens vencidos de outro usuário" do
    bob_list = @bob.lists.create!(title: "Bob")
    bob_list.items.create!(title: "Atrasado", user: @bob, due_date: 2.days.ago)
    get root_path
    assert_equal 0, assigns(:overdue_count)
  end

  # ─── Gráficos ─────────────────────────────────────────────────────────

  test "GET / retorna 7 dias no gráfico de barras" do
    @item.update!(completed: true)
    get root_path
    assert_equal 7, assigns(:completed_by_day).size
  end

  test "GET / dados do gráfico de prioridade escopados por usuário" do
    bob_list = @bob.lists.create!(title: "Bob")
    bob_list.items.create!(title: "Bob item", user: @bob, priority: :high)
    get root_path
    assert_nil assigns(:items_by_priority)["Alta"]
  end

  # ─── Radar por contexto ───────────────────────────────────────────────

  test "GET / radar vazio quando usuário não tem contextos com itens" do
    alice2 = User.create!(name: "Sem ctx", email: "semctx@test.com", password: "password123456")
    login_as(alice2)
    get root_path
    assert_empty assigns(:progress_by_context)
  end

  test "GET / radar com percentual correto por contexto" do
    @item.update!(completed: true)
    get root_path
    assert_equal 100, assigns(:progress_by_context)[@ctx.name]
  end

  # ─── Itens com prazo ──────────────────────────────────────────────────

  test "GET / lista itens com prazo do usuário atual" do
    @item.update!(due_date: 3.days.from_now)
    get root_path
    assert_includes assigns(:upcoming_items), @item
  end

  test "GET / não exibe itens com prazo de outro usuário" do
    bob_list = @bob.lists.create!(title: "Bob")
    bob_item = bob_list.items.create!(title: "Bob due", user: @bob, due_date: 1.day.from_now)
    get root_path
    assert_not_includes assigns(:upcoming_items), bob_item
  end

  # ─── Filtros dos gráficos ─────────────────────────────────────────────

  test "GET /?period=30 retorna 30 pontos no gráfico" do
    get root_path(period: 30)
    assert_equal 30, assigns(:completed_by_day).size
  end

  test "GET /?period= com valor inválido usa clamp (máximo 90)" do
    get root_path(period: 999)
    assert_equal 90, assigns(:chart_period)
  end

  test "GET /?chart_context_id= filtra pie chart pelo workspace" do
    other_ctx  = @alice.contexts.create!(name: "Pessoal")
    other_list = @alice.lists.create!(title: "Pessoal", context: other_ctx)
    other_list.items.create!(title: "Item pessoal", user: @alice, priority: :high)
    @item.update!(priority: :medium)

    get root_path(chart_context_id: @ctx.id)
    refute assigns(:items_by_priority).key?("Alta")
    assert assigns(:items_by_priority).key?("Média")
  end

  # ─── Atividade recente ────────────────────────────────────────────────

  test "GET / exibe atividade recente do usuário" do
    AuditLog.record(user: @alice, action: "created", auditable: @list, origin: "manual")
    get root_path
    assert assigns(:recent_activity).any?
  end

  test "GET / não exibe atividade de outro usuário" do
    bob_list = @bob.lists.create!(title: "Bob")
    AuditLog.record(user: @bob, action: "created", auditable: bob_list, origin: "manual")
    get root_path
    assert assigns(:recent_activity).none? { |l| l.user_id == @bob.id }
  end

  private

  def login_as(user)
    delete logout_path
    post login_path, params: { email: user.email, password: "password123456" }
  end
end
