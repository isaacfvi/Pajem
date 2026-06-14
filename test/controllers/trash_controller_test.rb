require "test_helper"

class TrashControllerTest < ActionDispatch::IntegrationTest
  def setup
    @alice = User.create!(name: "Alice", email: "alice@test.com", password: "password123456")
    @bob   = User.create!(name: "Bob",   email: "bob@test.com",   password: "password123456")

    @list = @alice.lists.create!(title: "Compras")
    @item = @list.items.create!(title: "Miojo", user: @alice)

    @list.discard
    @item.discard

    @bob_list = @bob.lists.create!(title: "Lista do Bob")
    @bob_list.discard

    login_as(@alice)
  end

  # ─── GET /lixeira ────────────────────────────────────────────────────

  test "GET /lixeira exibe listas e itens descartados do usuário" do
    get trash_path
    assert_response :success
    assert_match "Compras", response.body
    assert_match "Miojo", response.body
  end

  test "GET /lixeira não exibe itens de outros usuários" do
    get trash_path
    assert_no_match "Lista do Bob", response.body
  end

  test "GET /lixeira exibe estado vazio quando lixeira está vazia" do
    @list.destroy
    @item.reload.destroy rescue nil
    get trash_path
    assert_response :success
    assert_match "lixeira está vazia", response.body
  end

  test "GET /lixeira requer autenticação" do
    delete logout_path
    get trash_path
    assert_redirected_to login_path
  end

  # ─── PATCH /lixeira/listas/:id/restaurar ─────────────────────────────

  test "PATCH restaurar lista traz a lista de volta ao kept" do
    patch restore_trash_list_path(@list)
    assert_redirected_to trash_path
    assert_not @list.reload.discarded?
  end

  test "PATCH restaurar lista registra audit log" do
    assert_difference "AuditLog.count" do
      patch restore_trash_list_path(@list)
    end
    log = AuditLog.last
    assert_equal "restored", log.action
    assert_equal @list, log.auditable
  end

  test "PATCH restaurar lista alheia retorna 404" do
    patch restore_trash_list_path(@bob_list)
    assert_response :not_found
    assert @bob_list.reload.discarded?
  end

  test "PATCH restaurar lista não descartada retorna 404" do
    active_list = @alice.lists.create!(title: "Lista ativa")
    patch restore_trash_list_path(active_list)
    assert_response :not_found
  end

  # ─── PATCH /lixeira/itens/:id/restaurar ──────────────────────────────

  test "PATCH restaurar item traz o item de volta ao kept" do
    @list.undiscard
    patch restore_trash_item_path(@item)
    assert_redirected_to trash_path
    assert_not @item.reload.discarded?
  end

  test "PATCH restaurar item registra audit log" do
    @list.undiscard
    assert_difference "AuditLog.count" do
      patch restore_trash_item_path(@item)
    end
    log = AuditLog.last
    assert_equal "restored", log.action
    assert_equal @item, log.auditable
  end

  test "PATCH restaurar item bloqueia quando lista pai está descartada" do
    patch restore_trash_item_path(@item)
    assert_redirected_to trash_path
    assert @item.reload.discarded?
    assert_match "Restaure a lista", flash[:alert]
  end

  test "PATCH restaurar item alheio retorna 404" do
    bob_item = @bob_list.items.create!(title: "Feijão", user: @bob)
    bob_item.discard
    patch restore_trash_item_path(bob_item)
    assert_response :not_found
  end

  # ─── DELETE /lixeira/listas/:id ──────────────────────────────────────

  test "DELETE /lixeira/listas/:id destrói a lista permanentemente" do
    assert_difference "List.unscoped.count", -1 do
      delete trash_list_path(@list)
    end
    assert_redirected_to trash_path
  end

  test "DELETE /lixeira/listas/:id destrói os itens da lista" do
    assert_difference "Item.unscoped.count", -1 do
      delete trash_list_path(@list)
    end
  end

  test "DELETE /lixeira/listas/:id retorna 404 para lista alheia" do
    delete trash_list_path(@bob_list)
    assert_response :not_found
    assert List.unscoped.exists?(@bob_list.id)
  end

  # ─── DELETE /lixeira/itens/:id ───────────────────────────────────────

  test "DELETE /lixeira/itens/:id destrói o item permanentemente" do
    assert_difference "Item.unscoped.count", -1 do
      delete trash_item_path(@item)
    end
    assert_redirected_to trash_path
  end

  test "DELETE /lixeira/itens/:id retorna 404 para item alheio" do
    bob_item = @bob_list.items.create!(title: "Feijão", user: @bob)
    bob_item.discard
    delete trash_item_path(bob_item)
    assert_response :not_found
    assert Item.unscoped.exists?(bob_item.id)
  end

  private

  def login_as(user)
    delete logout_path
    post login_path, params: { email: user.email, password: "password123456" }
  end
end
