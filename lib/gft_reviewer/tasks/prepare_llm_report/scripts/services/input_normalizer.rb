# frozen_string_literal: true

require_relative "constants"

module PrepareLLMReport
  class InputNormalizer
    def initialize(payload)
      @payload = payload
    end

    def call
      raw  = payload[:input] || payload
      data = normalize_input(extract_llm_response(raw))
      data = data[:analysis_result] if analysis_result?(data)

      {
        place_id:       data[:place_id].to_s,
        language:       data[:language].to_s,
        place_data:     canonical_place_data(raw, data),
        reviews:        Array(data[:processed_reviews]),
        source_reviews: extract_source_reviews(raw)
      }
    end

    private

    attr_reader :payload

    def analysis_result?(data)
      data.is_a?(Hash) && data[:analysis_result].is_a?(Hash)
    end

    def extract_llm_response(raw)
      return raw unless raw.is_a?(Hash)
      return raw[:llm_data] if raw.key?(:llm_data) || raw.key?("llm_data")
      return raw[:llm_response] if raw.key?(:llm_response) || raw.key?("llm_response")

      raw
    end

    def extract_source_reviews(raw)
      return [] unless raw.is_a?(Hash)

      Array(raw.dig(:data, :reviews))
    end

    def canonical_place_data(raw, llm_data)
      source = extract_place_data(raw)
      return deep_symbolize(source) if source.any?

      deep_symbolize(llm_data[:place_data] || {})
    end

    def extract_place_data(raw)
      return {} unless raw.is_a?(Hash)

      raw.dig(:data, :place_data) || {}
    end

    def normalize_input(raw)
      return deep_symbolize(raw) if raw.is_a?(Hash)

      raise "AnalyzeReviews returned #{raw.class}, expected Hash"
    end

    def deep_symbolize(value)
      case value
      when Hash
        value.each_with_object({}) { |(key, nested), hash| hash[key.to_sym] = deep_symbolize(nested) }
      when Array
        value.map { |item| deep_symbolize(item) }
      else
        value
      end
    end
  end
end
