module Pajem
  class MessagesController < ApplicationController
    HISTORY_LIMIT = 10

    def create
      message_text = params[:message].to_s.strip
      return head :unprocessable_entity if message_text.blank?

      ChatMessage.create!(user: current_user, role: "user", content: message_text)

      history        = current_user.chat_messages.order(:created_at).last(HISTORY_LIMIT)
      last_assistant = history.select { |m| m.role == "assistant" }.last
      pending        = last_assistant&.metadata&.dig("pending_confirmation")

      content, metadata = pending ? handle_confirmation(message_text, pending) : handle_new_message(message_text, history)

      @assistant_message    = ChatMessage.create!(user: current_user, role: "assistant", content: content, metadata: metadata)
      @user_message_content = message_text

      respond_to do |format|
        format.turbo_stream
      end
    rescue Pajem::Errors::RateLimitError
      @error_message        = "Estarei de volta em breve — atingi meu limite de requisições por hoje."
      @user_message_content = params[:message].to_s.strip
      respond_to do |format|
        format.turbo_stream { render :create }
      end
    rescue => e
      Rails.logger.error "Pajem::MessagesController error — #{e.class}: #{e.message}"
      @error_message        = "O Pajem encontrou um problema. Tenta novamente."
      @user_message_content = params[:message].to_s.strip
      respond_to do |format|
        format.turbo_stream { render :create }
      end
    end

    private

    def handle_new_message(message_text, history)
      guardrails = Guardrails.new.call(message_text)
      return [ guardrails[:response], nil ] unless guardrails[:in_scope]

      clean_history = history.reject { |m| m.metadata&.dig("pending_confirmation").present? }
      result = Assistant.new(user: current_user).call(user_message: message_text, history: clean_history)

      if result[:type] == :confirmation_needed
        text     = build_confirmation_question(result[:tool], result[:params])
        metadata = { "pending_confirmation" => { "tool" => result[:tool], "params" => result[:params] } }
        return [ text, metadata ]
      end

      summary = build_summary(message_text, result[:tool_results])
      [ Responder.new.call(context: summary), nil ]
    end

    def handle_confirmation(message_text, pending)
      if user_confirmed?(message_text)
        tool_name   = pending["tool"]
        tool_params = (pending["params"] || {}).transform_keys(&:to_sym)
        result      = Tools.call(tool_name, user: current_user, **tool_params)
        text        = Responder.new.call(context: result[:message])
      else
        text = Responder.new.call(context: "O usuário cancelou a ação pendente. Confirme o cancelamento educadamente.")
      end
      [ text, nil ]
    end

    def build_confirmation_question(tool, params)
      resource = case tool
      when "delete_list"
        list = current_user.lists.find_by(id: params["list_id"].to_i)
        list ? "'#{list.title}'" : "esta lista"
      when "delete_item"
        item = current_user.items.find_by(id: params["item_id"].to_i)
        item ? "'#{item.title}'" : "este item"
      end
      "Tem certeza que deseja excluir #{resource}? Esta ação não pode ser desfeita. Responda *sim* para confirmar ou *não* para cancelar."
    end

    def build_summary(message_text, tool_results)
      # Skip read-only lookups and failures that were later recovered from
      any_write_success = tool_results.any? { |r| r[:success] && !Pajem::Tools::READONLY.include?(r[:tool]) }
      relevant = tool_results.reject do |r|
        Pajem::Tools::READONLY.include?(r[:tool]) ||
          (!r[:success] && any_write_success)
      end

      if relevant.empty?
        "Pedido do usuário: #{message_text}\nNenhuma ação foi necessária."
      else
        "Pedido do usuário: #{message_text}\nAções realizadas:\n" + relevant.map { |r| "- #{r[:message]}" }.join("\n")
      end
    end

    def user_confirmed?(message)
      message.match?(/\b(sim|s|yes|ok|confirmo|confirmar|pode|claro|com certeza|prossiga|exclua|execute)\b/i)
    end
  end
end
