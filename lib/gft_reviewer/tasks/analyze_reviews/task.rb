# frozen_string_literal: true

require_relative "output_schema"

module AnalyzeReviews
  MAX_REVIEWS  = 12

  class Task < BaseTask
    schema do
      param :place_id,   type: String, required: true
      param :language,   type: String, required: true
      param :place_data, type: Hash,   required: true
      param :reviews,    type: Array,  required: true

      use :review_scores
      use :review_patterns

      output OutputSchema, validate: :validate_response!, retries: 0
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
