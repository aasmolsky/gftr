# frozen_string_literal: true

require "json"
require_relative "constants"

module ParseReviews
  class InputNormalizer
    def initialize(payload)
      @payload = payload
    end

    def call
      raw  = payload[:input]
      data = normalize_input(raw)
      data = data[:analysis_result] if analysis_result?(data)

      {
        place_id:   data[:place_id].to_s,
        language:   data[:language].to_s,
        place_data: data[:place_data] || {},
        reviews:    Array(data[:processed_reviews])
      }
    end

    private

    attr_reader :payload

    def analysis_result?(data)
      data.is_a?(Hash) && data[:analysis_result].is_a?(Hash)
    end

    def normalize_input(raw)
      case raw
      when Hash
        deep_symbolize(raw)
      when String
        parse_legacy_string(raw)
      else
        raise "AnalyzeReviews returned #{raw.class}, expected Hash"
      end
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

    def parse_legacy_string(str)
      cleaned = str.to_s.gsub(/\A\s*```(?:json)?\s*/i, "").gsub(/\s*```\s*\z/, "").strip
      JSON.parse(cleaned, symbolize_names: true)
    rescue JSON::ParserError
      fixed = cleaned.gsub(/,(\s*[}\]])/, '\1')
      JSON.parse(fixed, symbolize_names: true)
    rescue JSON::ParserError => e
      raise "AnalyzeReviews returned malformed JSON: #{e.message}"
    end
  end
end
