require "test_helper"

class ItemsControllerTest < ActionDispatch::IntegrationTest
  TURBO = { "Accept" => "text/vnd.turbo-stream.html" }.freeze

  def setup
    @alice = User.create!(name: "Alice", email: "alice@test.com", password: "password123456")
    @bob   = User.create!(name: "Bob",   email: "bob@test.com",   password: "password123456")
    @list  = @alice.lists.create!(title: "Tarefas")
    @item  = @list.items.create!(title: "Item 1", user: @alice)
    login_as(@alice)
  end

  # ─── POST /listas/:list_id/itens ────────────────────────────────────

  test "POST cria item e retorna turbo_stream" do
    assert_difference "@list.items.count" do
      post list_items_path(@list), params: { item: { title: "Novo Item" } }, headers: TURBO
    end
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
  end

  test "POST redireciona HTML após criação" do
    assert_difference "@list.items.count" do
      post list_items_path(@list), params: { item: { title: "Novo Item" } }
    end
    assert_redirected_to lists_path
  end

  test "POST salva priority corretamente" do
    post list_items_path(@list), params: { item: { title: "Prioritário", priority: "high" } }
    assert @list.items.find_by(title: "Prioritário").priority_high?
  end

  test "POST com priority em branco salva nil" do
    post list_items_path(@list), params: { item: { title: "Sem prioridade", priority: "" } }
    assert_nil @list.items.find_by(title: "Sem prioridade").priority
  end

  test "POST sem título retorna erro via turbo_stream" do
    assert_no_difference "@list.items.count" do
      post list_items_path(@list), params: { item: { title: "" } }, headers: TURBO
    end
    assert_response :unprocessable_entity
  end

  test "POST retorna 404 para lista de outro usuário" do
    bob_list = @bob.lists.create!(title: "Lista do Bob")
    post list_items_path(bob_list), params: { item: { title: "Tentativa" } }
    assert_response :not_found
  end

  # ─── GET /listas/:list_id/itens/:id/editar ──────────────────────────

  test "GET edit renderiza formulário com título do item" do
    get edit_list_item_path(@list, @item)
    assert_response :success
    assert_match @item.title, response.body
  end

  test "GET edit retorna 404 para item de outro usuário" do
    bob_list = @bob.lists.create!(title: "Lista do Bob")
    bob_item = bob_list.items.create!(title: "Bob item", user: @bob)
    get edit_list_item_path(bob_list, bob_item)
    assert_response :not_found
  end

  # ─── PATCH /listas/:list_id/itens/:id ────────────────────────────────

  test "PATCH update atualiza título e redireciona" do
    patch list_item_path(@list, @item), params: { item: { title: "Título Novo" } }
    assert_redirected_to lists_path
    assert_equal "Título Novo", @item.reload.title
  end

  test "PATCH update falha com título em branco" do
    patch list_item_path(@list, @item), params: { item: { title: "" } }
    assert_response :unprocessable_entity
    assert_equal "Item 1", @item.reload.title
  end

  test "PATCH update retorna 404 para item de outro usuário" do
    bob_list = @bob.lists.create!(title: "Lista do Bob")
    bob_item = bob_list.items.create!(title: "Bob item", user: @bob)
    patch list_item_path(bob_list, bob_item), params: { item: { title: "Invadido" } }
    assert_response :not_found
    assert_equal "Bob item", bob_item.reload.title
  end

  # ─── PATCH /listas/:list_id/itens/:id/toggle ────────────────────────

  test "PATCH toggle marca item como completo" do
    patch toggle_list_item_path(@list, @item), headers: TURBO
    assert @item.reload.completed
    assert_response :success
  end

  test "PATCH toggle desmarca item completo" do
    @item.update!(completed: true)
    patch toggle_list_item_path(@list, @item), headers: TURBO
    assert_not @item.reload.completed
  end

  test "PATCH toggle redireciona HTML" do
    patch toggle_list_item_path(@list, @item)
    assert @item.reload.completed
    assert_redirected_to lists_path
  end

  test "PATCH toggle retorna 404 para item de outro usuário" do
    bob_list = @bob.lists.create!(title: "Lista do Bob")
    bob_item = bob_list.items.create!(title: "Bob item", user: @bob)
    patch toggle_list_item_path(bob_list, bob_item)
    assert_response :not_found
    assert_not bob_item.reload.completed
  end

  # ─── DELETE /listas/:list_id/itens/:id ──────────────────────────────

  test "DELETE faz soft delete e retorna turbo_stream" do
    delete list_item_path(@list, @item), headers: TURBO
    assert @item.reload.discarded?
    assert_response :success
  end

  test "DELETE redireciona HTML após exclusão" do
    delete list_item_path(@list, @item)
    assert @item.reload.discarded?
    assert_redirected_to lists_path
  end

  test "DELETE retorna 404 para item de outro usuário" do
    bob_list = @bob.lists.create!(title: "Lista do Bob")
    bob_item = bob_list.items.create!(title: "Bob item", user: @bob)
    delete list_item_path(bob_list, bob_item)
    assert_response :not_found
    assert_not bob_item.reload.discarded?
  end

  # ─── GET /listas/:list_id/itens (index + filtros) ───────────────────

  test "GET /itens retorna 200" do
    get list_items_path(@list)
    assert_response :success
  end

  test "GET /itens?q= filtra por título" do
    match   = @list.items.create!(title: "Estudar Rails", user: @alice)
    nomatch = @list.items.create!(title: "Comprar pão", user: @alice)
    get list_items_path(@list, q: "Rails")
    assert_includes assigns(:items), match
    assert_not_includes assigns(:items), nomatch
  end

  test "GET /itens?status=pending retorna apenas pendentes" do
    @item.update!(completed: false)
    done = @list.items.create!(title: "Feito", user: @alice, completed: true)
    get list_items_path(@list, status: "pending")
    assert_includes assigns(:items), @item
    assert_not_includes assigns(:items), done
  end

  test "GET /itens?status=done retorna apenas concluídos" do
    @item.update!(completed: true)
    pending = @list.items.create!(title: "Pendente", user: @alice)
    get list_items_path(@list, status: "done")
    assert_includes assigns(:items), @item
    assert_not_includes assigns(:items), pending
  end

  test "GET /itens?priority=high retorna apenas alta prioridade" do
    high = @list.items.create!(title: "Urgente", user: @alice, priority: :high)
    low  = @list.items.create!(title: "Opcional", user: @alice, priority: :low)
    get list_items_path(@list, priority: "high")
    assert_includes assigns(:items), high
    assert_not_includes assigns(:items), low
  end

  test "GET /itens?due=overdue retorna apenas vencidos" do
    overdue = @list.items.create!(title: "Atrasado", user: @alice, due_date: 2.days.ago)
    future  = @list.items.create!(title: "No prazo", user: @alice, due_date: 2.days.from_now)
    get list_items_path(@list, due: "overdue")
    assert_includes assigns(:items), overdue
    assert_not_includes assigns(:items), future
  end

  test "GET /itens aplica filtros compostos" do
    match  = @list.items.create!(title: "Rails urgente", user: @alice, priority: :high)
    wrong1 = @list.items.create!(title: "Rails simples", user: @alice, priority: :low)
    wrong2 = @list.items.create!(title: "Outro urgente", user: @alice, priority: :high)
    get list_items_path(@list, q: "Rails", priority: "high")
    assert_includes assigns(:items), match
    assert_not_includes assigns(:items), wrong1
    assert_not_includes assigns(:items), wrong2
  end

  test "GET /itens retorna 404 para lista de outro usuário" do
    bob_list = @bob.lists.create!(title: "Lista do Bob")
    get list_items_path(bob_list)
    assert_response :not_found
  end

  # ─── Autenticação ───────────────────────────────────────────────────

  test "redirecionamentos sem autenticação" do
    delete logout_path
    post list_items_path(@list), params: { item: { title: "X" } }
    assert_redirected_to login_path
  end

  private

  def login_as(user)
    delete logout_path
    post login_path, params: { email: user.email, password: "password123456" }
  end
end
