# frozen_string_literal: true

module PageProcessors
  class Base
    # @param url [String]
    # @param content [String] raw fetched content (HTML, XML, plain text, etc.)
    # @return [Hash, nil]
    def process(url, content)
      raise NotImplementedError, "#{self.class}#process not implemented"
    end
  end
end
