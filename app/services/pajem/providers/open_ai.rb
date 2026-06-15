require "net/http"
require "uri"
require "json"

module Pajem
  module Providers
    class OpenAi
      MODEL   = "gpt-4o-mini".freeze
      API_URL = "https://api.openai.com/v1/chat/completions".freeze

      def initialize
        @api_key = ENV["OPENAI_API_KEY"]
      end

      def generate(system:, messages:, tools: nil)
        body = build_body(system, messages, tools)
        raw  = post(body)
        parse(raw)
      end

      private

      def build_body(system, messages, tools)
        body = {
          model:       MODEL,
          temperature: 0.4,
          messages:    [ { role: "system", content: system }, *messages ]
        }
        if tools.present?
          body[:tools]                = tools
          body[:tool_choice]          = "auto"
          body[:parallel_tool_calls]  = false
        end
        body
      end

      def post(body)
        raise "OPENAI_API_KEY não configurada" unless @api_key

        uri  = URI(API_URL)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl      = true
        http.read_timeout = 45

        req = Net::HTTP::Post.new(uri.request_uri, {
          "Content-Type"  => "application/json",
          "Authorization" => "Bearer #{@api_key}"
        })
        req.body = body.to_json
        response = http.request(req)

        unless response.is_a?(Net::HTTPSuccess)
          raise Pajem::Errors::RateLimitError if response.code == "429"
          raise "OpenAI API error #{response.code}: #{response.body}"
        end

        JSON.parse(response.body, symbolize_names: true)
      end

      def parse(raw)
        message    = raw.dig(:choices, 0, :message) || {}
        tool_calls = (message[:tool_calls] || []).map do |tc|
          {
            id:   tc[:id],
            name: tc.dig(:function, :name),
            args: JSON.parse(tc.dig(:function, :arguments).presence || "{}", symbolize_names: true) || {}
          }
        end

        { content: message[:content].to_s.strip, tool_calls: tool_calls }
      end
    end
  end
end
