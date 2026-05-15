# frozen_string_literal: true

module PageProcessors
  class Null < Base
    def process(_url, _content)
      nil
    end
  end
end
