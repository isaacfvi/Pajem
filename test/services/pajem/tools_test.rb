require "test_helper"

class Pajem::ToolsTest < ActiveSupport::TestCase
  setup do
    @alice = User.create!(name: "Alice", email: "alice@tools.test", password: "password123456")
    @bob   = User.create!(name: "Bob",   email: "bob@tools.test",   password: "password123456")
    @ctx   = @alice.contexts.create!(name: "Trabalho")
    @list  = @alice.lists.create!(title: "Tarefas", context: @ctx)
    @item  = @list.items.create!(title: "Reunião", user: @alice)
  end

  # ─── list_lists ──────────────────────────────────────────────────────

  test "list_lists retorna listas ativas do usuário" do
    result = Pajem::Tools.list_lists(user: @alice)
    assert result[:success]
    assert_equal 1, result[:data].size
    assert_equal @list.id, result[:data].first[:id]
  end

  test "list_lists filtra por context_id" do
    other = @alice.lists.create!(title: "Pessoal")
    result = Pajem::Tools.list_lists(user: @alice, context_id: @ctx.id)
    ids = result[:data].map { |l| l[:id] }
    assert_includes ids, @list.id
    refute_includes ids, other.id
  end

  test "list_lists não retorna listas de outros usuários" do
    bob_list = @bob.lists.create!(title: "Bob")
    result = Pajem::Tools.list_lists(user: @alice)
    refute result[:data].map { |l| l[:id] }.include?(bob_list.id)
  end

  # ─── list_items ──────────────────────────────────────────────────────

  test "list_items retorna itens da lista" do
    result = Pajem::Tools.list_items(user: @alice, list_id: @list.id)
    assert result[:success]
    assert_equal 1, result[:data].size
    assert_equal @item.id, result[:data].first[:id]
  end

  test "list_items falha para lista inexistente ou de outro usuário" do
    bob_list = @bob.lists.create!(title: "Bob")
    result = Pajem::Tools.list_items(user: @alice, list_id: bob_list.id)
    refute result[:success]
  end

  # ─── list_contexts ───────────────────────────────────────────────────

  test "list_contexts retorna contextos do usuário" do
    result = Pajem::Tools.list_contexts(user: @alice)
    assert result[:success]
    assert_equal 1, result[:data].size
    assert_equal @ctx.id, result[:data].first[:id]
  end

  # ─── create_list ─────────────────────────────────────────────────────

  test "create_list cria lista e registra audit log" do
    assert_difference "AuditLog.count" do
      result = Pajem::Tools.create_list(user: @alice, title: "Nova Lista")
      assert result[:success]
      assert @alice.lists.exists?(title: "Nova Lista")
    end
  end

  test "create_list falha sem título" do
    result = Pajem::Tools.create_list(user: @alice, title: "")
    refute result[:success]
  end

  test "create_list aceita cor válida" do
    result = Pajem::Tools.create_list(user: @alice, title: "Colorida", color: "#FFF9C4")
    assert result[:success]
  end

  # ─── create_item ─────────────────────────────────────────────────────

  test "create_item cria item e registra audit log" do
    assert_difference "AuditLog.count" do
      result = Pajem::Tools.create_item(user: @alice, list_id: @list.id, title: "Novo Item")
      assert result[:success]
    end
  end

  test "create_item falha para lista de outro usuário" do
    bob_list = @bob.lists.create!(title: "Bob")
    result = Pajem::Tools.create_item(user: @alice, list_id: bob_list.id, title: "Hack")
    refute result[:success]
  end

  test "create_item aceita priority válida" do
    result = Pajem::Tools.create_item(user: @alice, list_id: @list.id, title: "Urgente", priority: "high")
    assert result[:success]
    assert_equal "high", @alice.items.find(result[:item_id]).priority
  end

  # ─── create_context ──────────────────────────────────────────────────

  test "create_context cria contexto e registra audit log" do
    assert_difference "AuditLog.count" do
      result = Pajem::Tools.create_context(user: @alice, name: "Pessoal")
      assert result[:success]
    end
  end

  # ─── set_context ─────────────────────────────────────────────────────

  test "set_context associa lista ao contexto" do
    list2 = @alice.lists.create!(title: "Outra Lista")
    result = Pajem::Tools.set_context(user: @alice, list_id: list2.id, context_id: @ctx.id)
    assert result[:success]
    assert_equal @ctx.id, list2.reload.context_id
  end

  test "set_context falha para contexto de outro usuário" do
    bob_ctx = @bob.contexts.create!(name: "Bob Ctx")
    result = Pajem::Tools.set_context(user: @alice, list_id: @list.id, context_id: bob_ctx.id)
    refute result[:success]
  end

  # ─── complete_item / uncomplete_item ─────────────────────────────────

  test "complete_item marca item como concluído" do
    result = Pajem::Tools.complete_item(user: @alice, item_id: @item.id)
    assert result[:success]
    assert @item.reload.completed
  end

  test "uncomplete_item desmarca item" do
    @item.update!(completed: true)
    result = Pajem::Tools.uncomplete_item(user: @alice, item_id: @item.id)
    assert result[:success]
    refute @item.reload.completed
  end

  test "complete_item falha para item de outro usuário" do
    bob_list = @bob.lists.create!(title: "Bob")
    bob_item = bob_list.items.create!(title: "Bob Item", user: @bob)
    result = Pajem::Tools.complete_item(user: @alice, item_id: bob_item.id)
    refute result[:success]
  end

  # ─── delete_list / delete_item ───────────────────────────────────────

  test "delete_list descarta lista e registra audit log" do
    assert_difference "AuditLog.count" do
      result = Pajem::Tools.delete_list(user: @alice, list_id: @list.id)
      assert result[:success]
    end
    assert_nil @alice.lists.find_by(id: @list.id)
  end

  test "delete_item descarta item e registra audit log" do
    assert_difference "AuditLog.count" do
      result = Pajem::Tools.delete_item(user: @alice, item_id: @item.id)
      assert result[:success]
    end
    assert_nil @alice.items.find_by(id: @item.id)
  end

  test "delete_list falha para lista de outro usuário" do
    bob_list = @bob.lists.create!(title: "Bob")
    result = Pajem::Tools.delete_list(user: @alice, list_id: bob_list.id)
    refute result[:success]
    assert bob_list.reload.kept?
  end
end
