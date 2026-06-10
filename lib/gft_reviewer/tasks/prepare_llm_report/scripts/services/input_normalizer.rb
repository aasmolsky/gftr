# frozen_string_literal: true

require_relative "constants"

module PrepareLLMReport
  class InputNormalizer
    def initialize(payload)
      @payload = payload
    end

    def call
      raw      = payload[:input] || payload
      llm_data = deep_symbolize(raw[:llm_data] || {})
      source   = deep_symbolize(raw[:data] || {})

      {
        place_id:       source[:place_id].to_s,
        language:       source[:language].to_s,
        place_data:     source[:place_data] || {},
        reviews:        Array(llm_data[:processed_reviews]),
        source_reviews: Array(source[:reviews])
      }
    end

    private

    attr_reader :payload

    def deep_symbolize(value)
      case value
      when Hash
        value.each_with_object({}) { |(k, v), h| h[k.to_sym] = deep_symbolize(v) }
      when Array
        value.map { |item| deep_symbolize(item) }
      else
        value
      end
    end
  end
end
