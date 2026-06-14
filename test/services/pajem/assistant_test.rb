require "test_helper"

class Pajem::AssistantTest < ActiveSupport::TestCase
  setup do
    @alice = User.create!(name: "Alice", email: "alice@assistant.test", password: "password123456")
  end

  def fn_call_response(name, args = {})
    { content: nil, tool_calls: [ { id: "call_#{name}", name: name, args: args } ] }
  end

  def text_response(text = "ok")
    { content: text, tool_calls: [] }
  end

  class FakeClient
    def initialize(*responses)
      @queue = responses.dup
    end

    def generate(**_kwargs)
      @queue.shift || { content: "done", tool_calls: [] }
    end
  end

  # ─── sem tool calls ───────────────────────────────────────────────────

  test "retorna completed sem tool_results quando LLM não chama tools" do
    client = FakeClient.new(text_response("Olá!"))
    result = Pajem::Assistant.new(user: @alice, client: client).call(user_message: "olá")
    assert_equal :completed, result[:type]
    assert_empty result[:tool_results]
  end

  # ─── com tool call ────────────────────────────────────────────────────

  test "executa ferramenta e retorna completed com tool_results" do
    client = FakeClient.new(
      fn_call_response("create_list", { title: "Compras" }),
      text_response("Lista criada!")
    )
    result = Pajem::Assistant.new(user: @alice, client: client).call(user_message: "cria lista Compras")
    assert_equal :completed, result[:type]
    assert @alice.lists.exists?(title: "Compras")
    assert result[:tool_results].any? { |r| r[:message].include?("Compras") }
  end

  # ─── delete interrompe o loop ─────────────────────────────────────────

  test "interrompe loop e retorna confirmation_needed ao solicitar delete_list" do
    list = @alice.lists.create!(title: "Deletar")
    client = FakeClient.new(fn_call_response("delete_list", { list_id: list.id }))
    result = Pajem::Assistant.new(user: @alice, client: client).call(user_message: "exclui a lista")
    assert_equal :confirmation_needed, result[:type]
    assert_equal "delete_list", result[:tool]
    assert list.reload.kept?
  end

  test "interrompe loop ao solicitar delete_item" do
    list = @alice.lists.create!(title: "Lista")
    item = list.items.create!(title: "Item", user: @alice)
    client = FakeClient.new(fn_call_response("delete_item", { item_id: item.id }))
    result = Pajem::Assistant.new(user: @alice, client: client).call(user_message: "exclui o item")
    assert_equal :confirmation_needed, result[:type]
    assert item.reload.kept?
  end

  # ─── limite de iterações ──────────────────────────────────────────────

  test "encerra ao atingir MAX_ITERATIONS sem loop infinito" do
    responses = Array.new(Pajem::Assistant::MAX_ITERATIONS) { fn_call_response("list_lists") }
    client = FakeClient.new(*responses)
    result = Pajem::Assistant.new(user: @alice, client: client).call(user_message: "teste")
    assert_equal :completed, result[:type]
    assert result[:tool_results].size <= Pajem::Assistant::MAX_ITERATIONS
  end

  # ─── múltiplas tools na mesma iteração ───────────────────────────────

  test "executa múltiplas tools agrupadas na mesma iteração" do
    list1 = @alice.lists.create!(title: "Lista 1")
    list2 = @alice.lists.create!(title: "Lista 2")
    list1.items.create!(title: "Item A", user: @alice)
    list2.items.create!(title: "Item B", user: @alice)

    parallel_response = {
      content: nil,
      tool_calls: [
        { id: "call_1", name: "list_items", args: { list_id: list1.id } },
        { id: "call_2", name: "list_items", args: { list_id: list2.id } }
      ]
    }

    client = FakeClient.new(parallel_response, text_response("done"))
    result = Pajem::Assistant.new(user: @alice, client: client).call(user_message: "o que tenho nas listas?")
    assert_equal :completed, result[:type]
    assert_equal 2, result[:tool_results].size
  end

  # ─── histórico ───────────────────────────────────────────────────────

  test "inclui histórico de mensagens no contexto" do
    history_msg = ChatMessage.new(role: "user", content: "mensagem anterior", user: @alice)
    calls = []
    client = Object.new
    client.define_singleton_method(:generate) do |**kwargs|
      calls << kwargs[:messages]
      { content: "ok", tool_calls: [] }
    end

    Pajem::Assistant.new(user: @alice, client: client).call(
      user_message: "nova mensagem",
      history: [ history_msg ]
    )

    first_call_messages = calls.first
    contents = first_call_messages.map { |m| m[:content] }
    assert_includes contents, "mensagem anterior"
  end
end
