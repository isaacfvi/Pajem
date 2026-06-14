module Pajem
  class LLMClient
    def initialize(provider: Pajem::Providers::Groq.new)
      @provider = provider
    end

    def generate(**kwargs)
      @provider.generate(**kwargs)
    end
  end
end
