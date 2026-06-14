require "test_helper"

class Pajem::GuardrailsTest < ActiveSupport::TestCase
  def text_response(text)
    { content: text, tool_calls: [] }
  end

  class FakeClient
    def initialize(responses)
      @queue = responses.dup
    end

    def generate(**_kwargs)
      @queue.shift
    end
  end

  test "passa mensagem dentro do escopo" do
    client = FakeClient.new([ text_response("DENTRO_DO_ESCOPO") ])
    result = Pajem::Guardrails.new(client: client).call("Cria uma lista de compras")
    assert result[:in_scope]
    assert_nil result[:response]
  end

  test "bloqueia mensagem fora do escopo e retorna recusa" do
    recusa = "FORA_DO_ESCOPO: Desculpe, só consigo ajudar com listas e itens."
    client = FakeClient.new([ text_response(recusa) ])
    result = Pajem::Guardrails.new(client: client).call("Escreve um poema")
    refute result[:in_scope]
    assert result[:response].present?
    refute_match "FORA_DO_ESCOPO", result[:response]
  end

  test "usa recusa padrão quando LLM não fornece texto após FORA_DO_ESCOPO" do
    client = FakeClient.new([ text_response("FORA_DO_ESCOPO:") ])
    result = Pajem::Guardrails.new(client: client).call("2 + 2?")
    refute result[:in_scope]
    assert result[:response].present?
  end
end
