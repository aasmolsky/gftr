require "json"

module GftReviewer
  class ReviewAnalysisPipeline < BasePipeline
    def call(input)
      scored = AnalyzeReviewsTask.call(
        place_id:   input[:place_id],
        language:   input[:language],
        place_data: input[:place_data],
        reviews:    input[:reviews]
      )

      scored_hash = scored.is_a?(Hash) ? scored : parse_llm_json(scored.to_s)

      scored_hash[:place_id]   = input[:place_id]
      scored_hash[:place_data] = input[:place_data]

      BuildReportTask.call(
        analysis_result: scored_hash,
        language:        input[:language]
      )
    end

    private

    def parse_llm_json(str)
      cleaned = strip_fences(str)
      JSON.parse(cleaned, symbolize_names: true)
    rescue JSON::ParserError
      fixed = cleaned.gsub(/,(\s*[}\]])/, '\1')
      JSON.parse(fixed, symbolize_names: true)
    rescue JSON::ParserError => e
      raise "LLM returned malformed JSON: #{e.message}\n\nRaw (first 500 chars):\n#{cleaned[0, 500]}"
    end

    def strip_fences(str)
      str.gsub(/\A\s*```(?:json)?\s*/i, "").gsub(/\s*```\s*\z/, "").strip
    end
  end
end

