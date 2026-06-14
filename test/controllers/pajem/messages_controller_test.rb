require "test_helper"

class Pajem::MessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alice = User.create!(name: "Alice", email: "alice@pajem.test", password: "password123456")
    login_as(@alice)
  end

  # ─── autenticação ─────────────────────────────────────────────────────

  test "redireciona para login sem autenticação" do
    delete logout_path
    post pajem_messages_path,
         params: { message: "cria uma lista" },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_redirected_to login_path
  end

  # ─── criação de mensagens ─────────────────────────────────────────────

  test "ignora mensagem em branco" do
    post pajem_messages_path,
         params: { message: "   " },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :unprocessable_entity
    assert_equal 0, @alice.chat_messages.count
  end

  test "salva mensagem do usuário e resposta do assistente" do
    with_stubs(
      [ Pajem::Guardrails, fake_service(:call, { in_scope: true }) ],
      [ Pajem::Assistant,  fake_service(:call, { type: :completed, tool_results: [] }) ],
      [ Pajem::Responder,  fake_service(:call, "Feito.") ]
    ) do
      assert_difference "ChatMessage.count", 2 do
        post pajem_messages_path,
             params: { message: "lista tudo" },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
      end
    end

    msgs = @alice.chat_messages.order(:created_at)
    assert_equal "user",      msgs.first.role
    assert_equal "assistant", msgs.last.role
  end

  test "retorna turbo stream" do
    with_stubs(
      [ Pajem::Guardrails, fake_service(:call, { in_scope: true }) ],
      [ Pajem::Assistant,  fake_service(:call, { type: :completed, tool_results: [] }) ],
      [ Pajem::Responder,  fake_service(:call, "Feito.") ]
    ) do
      post pajem_messages_path,
           params: { message: "olá" },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html; charset=utf-8", response.content_type
  end

  test "salva metadata quando assistente solicita confirmação" do
    list = @alice.lists.create!(title: "A Excluir")

    with_stubs(
      [ Pajem::Guardrails, fake_service(:call, { in_scope: true }) ],
      [ Pajem::Assistant,  fake_service(:call, { type: :confirmation_needed, tool: "delete_list", params: { "list_id" => list.id } }) ]
    ) do
      post pajem_messages_path,
           params: { message: "exclui a lista" },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    assistant_msg = @alice.chat_messages.where(role: "assistant").last
    assert assistant_msg.metadata["pending_confirmation"].present?
    assert_equal "delete_list", assistant_msg.metadata.dig("pending_confirmation", "tool")
  end

  test "executa delete após confirmação do usuário" do
    list = @alice.lists.create!(title: "A Excluir")
    pending = { "tool" => "delete_list", "params" => { "list_id" => list.id.to_s } }
    ChatMessage.create!(user: @alice, role: "assistant", content: "Confirma?",
                        metadata: { "pending_confirmation" => pending })

    with_stubs([ Pajem::Responder, fake_service(:call, "Excluído.") ]) do
      post pajem_messages_path,
           params: { message: "sim" },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    assert_nil @alice.lists.find_by(id: list.id)
  end

  private

  def login_as(user)
    delete logout_path
    post login_path, params: { email: user.email, password: "password123456" }
  end

  # Cria um objeto que responde a `method_name` devolvendo `return_value`
  def fake_service(method_name, return_value)
    Object.new.tap do |obj|
      obj.define_singleton_method(method_name) { |*_args, **_kwargs| return_value }
    end
  end

  # Substitui Class.new de cada klass por um fake durante o bloco,
  # restaurando ao final sem dependência de gem de mocking.
  def with_stubs(*pairs, &block)
    pairs.each { |klass, fake| klass.define_singleton_method(:new) { |*_a, **_k| fake } }
    block.call
  ensure
    pairs.each { |klass, _| klass.singleton_class.send(:remove_method, :new) rescue nil }
  end
end
