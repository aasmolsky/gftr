# frozen_string_literal: true

require_relative "output_schema"

module AnalyzeReviews
  class Task < BaseTask
    schema do
      param :place_id,   type: String, required: true
      param :language,   type: String, required: true
      param :place_data, type: Hash,   required: true
      param :reviews,    type: Array,  required: true

      use :review_scores
      use :review_patterns

      output OutputSchema, validate: :validate_response!, retries: 2
    end

    private

    def validate_response!(output, input)
      expected = Array(input[:reviews]).size
      actual   = Array(output[:processed_reviews]).size
      if expected != actual
        raise Frai::ValidationError,
              "processed_reviews must contain #{expected} items, got #{actual}"
      end

      if output[:place_id].to_s != input[:place_id].to_s
        raise Frai::ValidationError,
              "place_id mismatch: expected #{input[:place_id]}, got #{output[:place_id]}"
      end
    end
  end
end
