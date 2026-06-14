module Pajem
  module Tools
    READONLY = %w[ list_lists list_items list_contexts ].freeze

    def self.call(tool_name, user:, **params)
      case tool_name
      when "list_lists"     then list_lists(user: user, **params)
      when "list_items"     then list_items(user: user, **params)
      when "list_contexts"  then list_contexts(user: user)
      when "create_list"    then create_list(user: user, **params)
      when "create_item"    then create_item(user: user, **params)
      when "create_context" then create_context(user: user, **params)
      when "set_context"    then set_context(user: user, **params)
      when "complete_item"  then complete_item(user: user, **params)
      when "uncomplete_item" then uncomplete_item(user: user, **params)
      when "delete_list"    then delete_list(user: user, **params)
      when "delete_item"    then delete_item(user: user, **params)
      else { success: false, message: "Ferramenta '#{tool_name}' não reconhecida." }
      end
    rescue => e
      { success: false, message: "Erro interno: #{e.message}" }
    end

    def self.list_lists(user:, context_id: nil)
      scope = user.lists
      scope = scope.where(context_id: context_id.to_i) if context_id.present?
      data = scope.map { |l| { id: l.id, title: l.title, color: l.color, context_id: l.context_id } }
      { success: true, data: data, message: "#{data.size} lista(s) encontrada(s)." }
    end

    def self.list_items(user:, list_id:)
      list = user.lists.find_by(id: list_id.to_i)
      return { success: false, message: "Lista ##{list_id} não encontrada." } unless list

      data = list.items.map do |i|
        { id: i.id, title: i.title, completed: i.completed, due_date: i.due_date&.to_s, priority: i.priority }
      end
      { success: true, data: data, message: "#{data.size} item(ns) na lista '#{list.title}'." }
    end

    def self.list_contexts(user:)
      data = user.contexts.map { |c| { id: c.id, name: c.name } }
      { success: true, data: data, message: "#{data.size} contexto(s) encontrado(s)." }
    end

    def self.create_list(user:, title:, color: nil, context_id: nil)
      context = context_id.present? ? user.contexts.find_by(id: context_id.to_i) : nil
      list = user.lists.new(title: title, color: color.presence, context: context)
      if list.save
        AuditLog.record(user: user, action: "created", auditable: list, origin: "assistant")
        { success: true, message: "Lista '#{list.title}' criada com sucesso.", list_id: list.id }
      else
        { success: false, message: "Erro ao criar lista: #{list.errors.full_messages.join(', ')}" }
      end
    end

    def self.create_item(user:, list_id:, title:, due_date: nil, priority: nil)
      list = user.lists.find_by(id: list_id.to_i)
      return { success: false, message: "Lista ##{list_id} não encontrada." } unless list

      attrs = { title: title, user: user }
      attrs[:due_date] = Date.parse(due_date) if due_date.present?
      attrs[:priority] = priority if priority.present? && Item.priorities.key?(priority.to_s)

      item = list.items.new(attrs)
      if item.save
        AuditLog.record(user: user, action: "created", auditable: item, origin: "assistant")
        { success: true, message: "Item '#{item.title}' criado na lista '#{list.title}'.", item_id: item.id }
      else
        { success: false, message: "Erro ao criar item: #{item.errors.full_messages.join(', ')}" }
      end
    end

    def self.create_context(user:, name:)
      context = user.contexts.new(name: name)
      if context.save
        AuditLog.record(user: user, action: "created", auditable: context, origin: "assistant")
        { success: true, message: "Contexto '#{context.name}' criado com sucesso.", context_id: context.id }
      else
        { success: false, message: "Erro ao criar contexto: #{context.errors.full_messages.join(', ')}" }
      end
    end

    def self.set_context(user:, list_id:, context_id:)
      list    = user.lists.find_by(id: list_id.to_i)
      return { success: false, message: "Lista ##{list_id} não encontrada." } unless list

      context = user.contexts.find_by(id: context_id.to_i)
      return { success: false, message: "Contexto ##{context_id} não encontrado." } unless context

      if list.update(context: context)
        AuditLog.record(user: user, action: "updated", auditable: list, origin: "assistant")
        { success: true, message: "Lista '#{list.title}' associada ao contexto '#{context.name}'." }
      else
        { success: false, message: "Erro ao associar contexto." }
      end
    end

    def self.complete_item(user:, item_id:)
      item = user.items.find_by(id: item_id.to_i)
      return { success: false, message: "Item ##{item_id} não encontrado." } unless item

      if item.update(completed: true)
        AuditLog.record(user: user, action: "completed", auditable: item, origin: "assistant")
        { success: true, message: "Item '#{item.title}' concluído." }
      else
        { success: false, message: "Erro ao concluir item." }
      end
    end

    def self.uncomplete_item(user:, item_id:)
      item = user.items.find_by(id: item_id.to_i)
      return { success: false, message: "Item ##{item_id} não encontrado." } unless item

      if item.update(completed: false)
        AuditLog.record(user: user, action: "uncompleted", auditable: item, origin: "assistant")
        { success: true, message: "Item '#{item.title}' desmarcado." }
      else
        { success: false, message: "Erro ao desmarcar item." }
      end
    end

    def self.delete_list(user:, list_id:)
      list = user.lists.find_by(id: list_id.to_i)
      return { success: false, message: "Lista ##{list_id} não encontrada." } unless list

      list.discard
      AuditLog.record(user: user, action: "deleted", auditable: list, origin: "assistant")
      { success: true, message: "Lista '#{list.title}' excluída." }
    end

    def self.delete_item(user:, item_id:)
      item = user.items.find_by(id: item_id.to_i)
      return { success: false, message: "Item ##{item_id} não encontrado." } unless item

      item.discard
      AuditLog.record(user: user, action: "deleted", auditable: item, origin: "assistant")
      { success: true, message: "Item '#{item.title}' excluído." }
    end
  end
end
