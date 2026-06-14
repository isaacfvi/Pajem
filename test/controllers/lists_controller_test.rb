require "test_helper"

class ListsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @alice = User.create!(name: "Alice", email: "alice@test.com", password: "password123456")
    @bob   = User.create!(name: "Bob",   email: "bob@test.com",   password: "password123456")
    @ctx   = @alice.contexts.create!(name: "Trabalho")
    @list  = @alice.lists.create!(title: "Tarefas", context: @ctx)
    login_as(@alice)
  end

  # ─── GET /listas ──────────────────────────────────────────────────────

  test "GET /listas exibe listas do usuário" do
    get lists_path
    assert_response :success
    assert_match @list.title, response.body
  end

  test "GET /listas não exibe listas de outros usuários" do
    bob_list = @bob.lists.create!(title: "Lista do Bob")
    get lists_path
    assert_no_match bob_list.title, response.body
  end

  test "GET /listas filtra por context_id" do
    outro = @alice.lists.create!(title: "Sem contexto")
    get lists_path(context_id: @ctx.id)
    assert_match @list.title, response.body
    assert_no_match outro.title, response.body
  end

  test "GET /listas ignora context_id de outro usuário" do
    bob_ctx = @bob.contexts.create!(name: "Bob Trabalho")
    get lists_path(context_id: bob_ctx.id)
    assert_match @list.title, response.body
  end

  test "GET /listas não exibe listas descartadas" do
    @list.discard
    get lists_path
    assert_no_match @list.title, response.body
  end

  test "GET /listas redireciona para login sem autenticação" do
    delete logout_path
    get lists_path
    assert_redirected_to login_path
  end

  # ─── GET /listas/nova ─────────────────────────────────────────────────

  test "GET /listas/nova renderiza formulário" do
    get new_list_path
    assert_response :success
  end

  test "GET /listas/nova redireciona para login sem autenticação" do
    delete logout_path
    get new_list_path
    assert_redirected_to login_path
  end

  # ─── POST /listas ─────────────────────────────────────────────────────

  test "POST /listas cria lista com título válido" do
    assert_difference "@alice.lists.count" do
      post lists_path, params: { list: { title: "Nova Tarefa" } }
    end
    assert_redirected_to lists_path
  end

  test "POST /listas cria lista com cor e contexto" do
    cor = List::PALETTE.first[:bg]
    assert_difference "@alice.lists.count" do
      post lists_path, params: { list: { title: "Colorida", color: cor, context_id: @ctx.id } }
    end
    criada = @alice.lists.find_by(title: "Colorida")
    assert_equal cor, criada.color
    assert_equal @ctx.id, criada.context_id
  end

  test "POST /listas converte cor vazia em nil" do
    post lists_path, params: { list: { title: "Sem cor", color: "" } }
    assert_nil @alice.lists.find_by(title: "Sem cor").color
  end

  test "POST /listas falha sem título" do
    assert_no_difference "@alice.lists.count" do
      post lists_path, params: { list: { title: "" } }
    end
    assert_response :unprocessable_entity
  end

  test "POST /listas falha com cor fora da paleta" do
    assert_no_difference "@alice.lists.count" do
      post lists_path, params: { list: { title: "Cor ruim", color: "#FF5C13" } }
    end
    assert_response :unprocessable_entity
  end

  # ─── GET /listas/:id/editar ───────────────────────────────────────────

  test "GET /listas/:id/editar renderiza formulário pré-preenchido" do
    get edit_list_path(@list)
    assert_response :success
    assert_match @list.title, response.body
  end

  test "GET /listas/:id/editar retorna 404 para lista de outro usuário" do
    bob_list = @bob.lists.create!(title: "Lista do Bob")
    get edit_list_path(bob_list)
    assert_response :not_found
  end

  # ─── PATCH /listas/:id ────────────────────────────────────────────────

  test "PATCH /listas/:id atualiza o título" do
    patch list_path(@list), params: { list: { title: "Título Novo" } }
    assert_redirected_to lists_path
    assert_equal "Título Novo", @list.reload.title
  end

  test "PATCH /listas/:id atualiza o contexto" do
    novo_ctx = @alice.contexts.create!(name: "Pessoal")
    patch list_path(@list), params: { list: { title: @list.title, context_id: novo_ctx.id } }
    assert_equal novo_ctx.id, @list.reload.context_id
  end

  test "PATCH /listas/:id limpa a cor com string vazia" do
    @list.update!(color: List::PALETTE.first[:bg])
    patch list_path(@list), params: { list: { title: @list.title, color: "" } }
    assert_nil @list.reload.color
  end

  test "PATCH /listas/:id falha com título em branco" do
    patch list_path(@list), params: { list: { title: "" } }
    assert_response :unprocessable_entity
    assert_equal "Tarefas", @list.reload.title
  end

  test "PATCH /listas/:id retorna 404 para lista de outro usuário" do
    bob_list = @bob.lists.create!(title: "Lista do Bob")
    patch list_path(bob_list), params: { list: { title: "Invadida" } }
    assert_response :not_found
    assert_equal "Lista do Bob", bob_list.reload.title
  end

  # ─── DELETE /listas/:id ───────────────────────────────────────────────

  test "DELETE /listas/:id faz soft delete da lista" do
    delete list_path(@list)
    assert_redirected_to lists_path
    assert @list.reload.discarded?
  end

  test "DELETE /listas/:id lista não aparece mais no index" do
    delete list_path(@list)
    get lists_path
    assert_select ".postit__title", text: @list.title, count: 0
  end

  test "DELETE /listas/:id retorna 404 para lista de outro usuário" do
    bob_list = @bob.lists.create!(title: "Lista do Bob")
    delete list_path(bob_list)
    assert_response :not_found
    assert_not bob_list.reload.discarded?
  end

  # ─── PATCH /listas/:id/compartilhar ──────────────────────────────

  test "PATCH compartilhar ativa o compartilhamento e gera token" do
    patch compartilhar_list_path(@list)
    @list.reload
    assert @list.share_enabled?
    assert @list.share_token.present?
  end

  test "PATCH compartilhar desativa quando já está ativo" do
    @list.update!(share_enabled: true, share_token: "abc")
    patch compartilhar_list_path(@list)
    assert_not @list.reload.share_enabled?
  end

  test "PATCH compartilhar registra audit log" do
    assert_difference "AuditLog.count" do
      patch compartilhar_list_path(@list)
    end
    log = AuditLog.last
    assert_equal "shared", log.action
    assert_equal @list, log.auditable
  end

  test "PATCH compartilhar registra audit log de unshared ao desativar" do
    @list.update!(share_enabled: true, share_token: "abc")
    patch compartilhar_list_path(@list)
    assert_equal "unshared", AuditLog.last.action
  end

  test "PATCH compartilhar retorna 404 para lista de outro usuário" do
    bob_list = @bob.lists.create!(title: "Bob Share")
    patch compartilhar_list_path(bob_list)
    assert_response :not_found
  end

  # ─── PATCH /listas/:id/revogar_link ──────────────────────────────

  test "PATCH revogar_link gera novo token mantendo link ativo" do
    @list.update!(share_enabled: true, share_token: "token-antigo")
    patch revogar_link_list_path(@list)
    @list.reload
    assert @list.share_enabled?
    assert_not_equal "token-antigo", @list.share_token
  end

  test "PATCH revogar_link registra audit log de shared" do
    @list.update!(share_enabled: true, share_token: "tok")
    assert_difference "AuditLog.count" do
      patch revogar_link_list_path(@list)
    end
    assert_equal "shared", AuditLog.last.action
  end

  test "PATCH revogar_link retorna 404 para lista de outro usuário" do
    bob_list = @bob.lists.create!(title: "Bob Revoke", share_enabled: true, share_token: "x")
    patch revogar_link_list_path(bob_list)
    assert_response :not_found
  end

  private

  def login_as(user)
    delete logout_path
    post login_path, params: { email: user.email, password: "password123456" }
  end
end
