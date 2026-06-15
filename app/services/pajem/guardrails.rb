module Pajem
  class Guardrails
    def initialize(client: Pajem::LLMClient.new)
      @client = client
    end

    def call(message, history: [])
      messages = history.map { |m| { role: m.role, content: m.content } }
      messages << { role: "user", content: message }

      response = @client.generate(system: system_prompt, messages: messages)
      text = response[:content].to_s.strip

      if text.match?(/\AFORA_DO_ESCOPO/i)
        { in_scope: false, response: default_refusal }
      else
        { in_scope: true }
      end
    end

    private

    def default_refusal
      "Desculpe, só consigo ajudar com listas, itens e contextos."
    end

    def system_prompt
      <<~PROMPT
        Você é um classificador de mensagens para o assistente Pajem, que gerencia listas e itens.

        O Pajem aceita QUALQUER mensagem que possa resultar em uma ação numa lista ou item — adicionar, concluir, criar, listar, excluir. Isso inclui:
        - Comandos diretos: "adiciona X", "marca Y como feito", "cria lista de Z"
        - Intenções e ideias: "quero fazer X", "tive uma ideia de Y", "pensei em Z"
        - Realizações: "acabei de fazer X", "finalizei Y", "terminei de ler Z"
        - Qualquer assunto mencionado como algo que o usuário fez, quer fazer ou quer lembrar

        Responda "FORA_DO_ESCOPO: [recusa]" APENAS para mensagens que CLARAMENTE não têm relação alguma com listas ou registro de informações:
        - Perguntas de trivia ou conhecimento geral ("qual a capital da França?")
        - Pedidos de piadas, poemas ou traduções de texto
        - Cálculos matemáticos puros ("quanto é 15% de 230?")
        - Conteúdo ofensivo

        EXEMPLOS DE ZONA CINZA — todos são DENTRO_DO_ESCOPO:
        - "acabei de finalizar meu dashboard com IA" → realizaçao que pode virar item concluído
        - "tive uma ideia de escrever uma campanha de RPG" → ideia que pode virar item numa lista
        - "quero aprender Rust" → intenção que pode virar item numa lista de objetivos
        - "li O Nome do Vento" → pode marcar como lido numa lista de leituras
        - "preciso comprar tênis" → item implícito de lista de compras
        - "me lembra de ligar pro dentista" → item de tarefas
        - "terminei o curso de React" → realização que pode virar item concluído

        Qualquer dúvida: responda "DENTRO_DO_ESCOPO".
        Responda SOMENTE com "DENTRO_DO_ESCOPO" ou "FORA_DO_ESCOPO: [mensagem]". Nada mais.
      PROMPT
    end
  end
end
