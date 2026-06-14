module Pajem
  class MessagesController < ApplicationController
    HISTORY_LIMIT = 10

    def create
      message_text = params[:message].to_s.strip
      return head :unprocessable_entity if message_text.blank?

      ChatMessage.create!(user: current_user, role: "user", content: message_text)

      history = current_user.chat_messages.order(:created_at).last(HISTORY_LIMIT)

      content, metadata = handle_new_message(message_text, history)

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

      result = Assistant.new(user: current_user).call(user_message: message_text, history: history)
      summary = build_summary(message_text, result[:tool_results])
      [ Responder.new.call(context: summary), nil ]
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

  end
end
