# frozen_string_literal: true

require_relative "llm_schemas/output_schema"

module AnalyzeReviews
  MAX_REVIEWS  = 12

  class Task < BaseTask
    schema do
      param :place_id,   type: String, required: true
      param :language,   type: String, required: true
      param :reviews, type: Array, required: true
      param :place_data, type: Hash,   required: true do
        required(:title).filled(:string)
        required(:rating).filled(:float)
        required(:reviews_count).filled(:integer)
        required(:address).filled(:string)
      end

      directive :task do
        use :review_scores
        use :review_patterns
      end

      output LLMSchemas::OutputSchema, validate: :validate_response!, retries: 0
    end

    private

    def validate_response!(output, input)
      expected = Array(input[:reviews]).size
      actual   = Array(output[:processed_reviews]).size

      return if expected == actual

      raise Frai::ValidationError,
            "processed_reviews must contain #{expected} items, got #{actual}"
    end
  end
end
