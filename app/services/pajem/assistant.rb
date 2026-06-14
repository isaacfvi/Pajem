module Pajem
  class Assistant
    MAX_ITERATIONS   = 6
    DESTRUCTIVE_TOOLS = %w[ delete_list delete_item ].freeze

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

        # Interrupt for destructive tools — do not execute, await confirmation
        destructive = tool_calls.find { |tc| DESTRUCTIVE_TOOLS.include?(tc[:name]) }
        if destructive
          return {
            type:   :confirmation_needed,
            tool:   destructive[:name],
            params: (destructive[:args] || {}).transform_keys(&:to_s)
          }
        end

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

        FLUXO OBRIGATÓRIO — siga sempre esta ordem:

        Para criar um item numa lista:
          1. list_lists → obter o list_id real
          2. create_item com o list_id real

        Para completar, desmarcar ou excluir um item:
          1. list_lists → obter o list_id real
          2. list_items com o list_id real → obter o item_id real
          3. complete_item / uncomplete_item / delete_item com o item_id real

        Para criar lista ou contexto: execute diretamente (não precisa de lookup).

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
