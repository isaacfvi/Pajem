module Pajem
  module ToolDefinitions
    LOOKUP_TOOLS = %w[ list_lists list_items list_contexts ].freeze

    def self.all
      TOOLS.map { |t| { type: "function", function: t } }
    end

    def self.actions
      TOOLS.reject { |t| LOOKUP_TOOLS.include?(t[:name]) }
           .map { |t| { type: "function", function: t } }
    end

    TOOLS = [
      {
        name: "list_lists",
        description: "Retorna as listas ativas do usuário. Use para descobrir quais listas existem antes de agir.",
        parameters: {
          type: "object",
          properties: {
            context_id: { description: "ID do contexto para filtrar (opcional)" }
          }
        }
      },
      {
        name: "list_items",
        description: "Retorna os itens ativos de uma lista específica.",
        parameters: {
          type: "object",
          properties: {
            list_id: { description: "ID da lista" }
          },
          required: [ "list_id" ]
        }
      },
      {
        name: "list_contexts",
        description: "Retorna todos os contextos do usuário.",
        parameters: {
          type: "object",
          properties: {}
        }
      },
      {
        name: "create_list",
        description: "Cria uma nova lista para o usuário.",
        parameters: {
          type: "object",
          properties: {
            title: { type: "string", description: "Título da lista" },
            color: {
              type: "string",
              description: "Cor em hex: #FFF9C4 amarelo, #DCEDC8 verde, #BBDEFB azul, #FCE4EC rosa, #FFE0B2 laranja, #E1BEE7 lilás, #FFCDD2 vermelho, #B2DFDB menta"
            },
            context_id: { description: "ID do contexto ao qual associar (opcional)" }
          },
          required: [ "title" ]
        }
      },
      {
        name: "create_item",
        description: "Cria um novo item dentro de uma lista.",
        parameters: {
          type: "object",
          properties: {
            list_id:  { description: "ID da lista" },
            title:    { type: "string",  description: "Título do item" },
            due_date: { type: "string",  description: "Data de vencimento YYYY-MM-DD (opcional)" },
            priority: { type: "string",  description: "Prioridade: low, medium ou high (opcional)" }
          },
          required: [ "list_id", "title" ]
        }
      },
      {
        name: "create_context",
        description: "Cria um novo contexto para agrupar listas.",
        parameters: {
          type: "object",
          properties: {
            name: { type: "string", description: "Nome do contexto" }
          },
          required: [ "name" ]
        }
      },
      {
        name: "set_context",
        description: "Associa uma lista a um contexto.",
        parameters: {
          type: "object",
          properties: {
            list_id:    { description: "ID da lista" },
            context_id: { description: "ID do contexto" }
          },
          required: [ "list_id", "context_id" ]
        }
      },
      {
        name: "complete_item",
        description: "Marca um item como concluído.",
        parameters: {
          type: "object",
          properties: {
            item_id: { description: "ID do item" }
          },
          required: [ "item_id" ]
        }
      },
      {
        name: "uncomplete_item",
        description: "Remove a marcação de concluído de um item.",
        parameters: {
          type: "object",
          properties: {
            item_id: { description: "ID do item" }
          },
          required: [ "item_id" ]
        }
      },
      {
        name: "delete_list",
        description: "Exclui permanentemente uma lista e todos os seus itens. Requer confirmação do usuário — NÃO execute diretamente.",
        parameters: {
          type: "object",
          properties: {
            list_id: { description: "ID da lista" }
          },
          required: [ "list_id" ]
        }
      },
      {
        name: "delete_item",
        description: "Exclui permanentemente um item. Requer confirmação do usuário — NÃO execute diretamente.",
        parameters: {
          type: "object",
          properties: {
            item_id: { description: "ID do item" }
          },
          required: [ "item_id" ]
        }
      }
    ].freeze
  end
end
