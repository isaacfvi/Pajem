module Pajem
  class Assistant
    MAX_ITERATIONS = 6

    def initialize(user:, client: Pajem::LLMClient.new)
      @user   = user
      @client = client
    end

    def call(user_message:, history: [])
      messages     = build_messages(history, user_message)
      tool_results = []

      MAX_ITERATIONS.times do
        response   = @client.generate(system: system_prompt, messages: messages, tools: ToolDefinitions.all)
        tool_calls = response[:tool_calls]
        break if tool_calls.empty?

        # Record assistant turn in OpenAI format so Groq can match tool results
        messages << {
          role:       "assistant",
          content:    nil,
          tool_calls: tool_calls.map { |tc|
            { id: tc[:id], type: "function", function: { name: tc[:name], arguments: tc[:args].to_json } }
          }
        }

        # Execute tools and append results
        tool_calls.each do |tc|
          result = Tools.call(tc[:name], user: @user, **(tc[:args] || {}).transform_keys(&:to_sym))
          tool_results << result.merge(tool: tc[:name])
          messages << { role: "tool", tool_call_id: tc[:id], content: result.to_json }
        end
      end

      { type: :completed, tool_results: tool_results }
    end

    private

    def build_messages(history, user_message)
      msgs = history.map { |m| { role: m.role, content: m.content } }
      msgs << { role: "user", content: user_message }
      msgs
    end

    def system_prompt
      <<~PROMPT
        Você é o Pajem, assistente que executa ações em listas, itens e contextos do usuário.
        Sua função é agir, não perguntar. Nunca recuse um pedido por falta de informação — use as ferramentas para obtê-la.

        PRIMEIRA ETAPA OBRIGATÓRIA — antes de qualquer ação:
          Chame list_contexts e list_lists para conhecer o estado atual do usuário.
          Isso evita criar duplicatas e garante que você use IDs reais.

        FLUXO OBRIGATÓRIO — após o lookup inicial:

        Para criar um item numa lista:
          1. list_items com o list_id da lista alvo → obter o item_id real se necessário
          2. create_item com o list_id real

        Para completar, desmarcar ou excluir um item:
          1. list_items com o list_id real → obter o item_id real
          2. complete_item / uncomplete_item / delete_item com o item_id real

        Para excluir uma lista:
          1. delete_list com o list_id real (já obtido no lookup inicial)

        Para criar uma lista com contexto mencionado pelo nome:
          1. Verificar nos resultados do lookup se o contexto já existe
          2. Se existir: create_list com o context_id real
          3. Se não existir: create_context → depois create_list com o novo context_id

        Para criar contexto: verificar no lookup se já existe antes de criar.

        REGRAS:
        - Cada passo acima é uma iteração separada. Nunca pule etapas.
        - NUNCA invente ou adivinhe um ID. Se não tem o ID em mãos, chame a ferramenta de lookup primeiro.
        - NUNCA passe uma chamada de ferramenta como argumento de outra.
        - NUNCA peça ao usuário que forneça IDs.
        - Quando todos os IDs necessários já estiverem disponíveis no contexto, execute a ação.
      PROMPT
    end
  end
end
