require "test_helper"

class ContextsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @alice = User.create!(name: "Alice", email: "alice@example.com", password: "password123456")
    @bob   = User.create!(name: "Bob",   email: "bob@example.com",   password: "password123456")
    @context = @alice.contexts.create!(name: "Trabalho")
    login_as(@alice)
  end

  # ─── GET /contextos/novo ────────────────────────────────────────────

  test "GET /contextos/novo renderiza formulário" do
    get new_context_path
    assert_response :success
  end

  test "GET /contextos/novo sem autenticação redireciona para login" do
    delete logout_path
    get new_context_path
    assert_redirected_to login_path
  end

  # ─── POST /contextos ────────────────────────────────────────────────

  test "POST /contextos cria contexto com nome válido" do
    assert_difference "@alice.contexts.count" do
      post contexts_path, params: { context: { name: "Estudos" } }
    end
    assert_redirected_to lists_path(context_id: Context.last.id)
    assert_equal "Estudos", Context.last.name
  end

  test "POST /contextos falha com nome em branco" do
    assert_no_difference "@alice.contexts.count" do
      post contexts_path, params: { context: { name: "" } }
    end
    assert_response :unprocessable_entity
  end

  test "POST /contextos falha com nome duplicado para o mesmo usuário" do
    assert_no_difference "@alice.contexts.count" do
      post contexts_path, params: { context: { name: "Trabalho" } }
    end
    assert_response :unprocessable_entity
  end

  test "POST /contextos permite mesmo nome para usuários diferentes" do
    login_as(@bob)
    assert_difference "@bob.contexts.count" do
      post contexts_path, params: { context: { name: "Trabalho" } }
    end
    assert_response :redirect
  end

  # ─── GET /contextos/:id/editar ──────────────────────────────────────

  test "GET /contextos/:id/editar renderiza formulário pré-preenchido" do
    get edit_context_path(@context)
    assert_response :success
  end

  test "GET /contextos/:id/editar retorna 404 para contexto de outro usuário" do
    bob_context = @bob.contexts.create!(name: "Bob Contexto")
    get edit_context_path(bob_context)
    assert_response :not_found
  end

  # ─── PATCH /contextos/:id ───────────────────────────────────────────

  test "PATCH /contextos/:id atualiza o nome" do
    patch context_path(@context), params: { context: { name: "Trabalho Remoto" } }
    assert_redirected_to lists_path(context_id: @context.id)
    assert_equal "Trabalho Remoto", @context.reload.name
  end

  test "PATCH /contextos/:id falha com nome em branco" do
    patch context_path(@context), params: { context: { name: "" } }
    assert_response :unprocessable_entity
    assert_equal "Trabalho", @context.reload.name
  end

  test "PATCH /contextos/:id retorna 404 para contexto de outro usuário" do
    bob_context = @bob.contexts.create!(name: "Bob Contexto")
    patch context_path(bob_context), params: { context: { name: "Invadido" } }
    assert_response :not_found
    assert_equal "Bob Contexto", bob_context.reload.name
  end

  # ─── DELETE /contextos/:id ──────────────────────────────────────────

  test "DELETE /contextos/:id exclui o contexto" do
    assert_difference "@alice.contexts.count", -1 do
      delete context_path(@context)
    end
    assert_redirected_to lists_path
  end

  test "DELETE /contextos/:id mantém listas associadas com context_id nil" do
    list = @alice.lists.create!(title: "Minha Lista", context: @context)
    delete context_path(@context)
    assert_nil list.reload.context_id
  end

  test "DELETE /contextos/:id retorna 404 para contexto de outro usuário" do
    bob_context = @bob.contexts.create!(name: "Bob Contexto")
    assert_no_difference "Context.count" do
      delete context_path(bob_context)
    end
    assert_response :not_found
  end

  private

  def login_as(user)
    delete logout_path
    post "/login", params: { email: user.email, password: "password123456" }
  end
end
