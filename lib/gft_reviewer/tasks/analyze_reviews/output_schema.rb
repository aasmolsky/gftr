# frozen_string_literal: true

require "ruby_llm/schema"

module AnalyzeReviews
  class ScoreBreakdownSchema < RubyLLM::Schema
    additional_properties true
  end

  class ProcessedReviewSchema < RubyLLM::Schema
    string  :review_id
    integer :rating
    string  :author_name
    string  :snippet

    object :score_breakdown, of: ScoreBreakdownSchema
  end

  class OutputSchema < RubyLLM::Schema
    string :place_id
    string :language

    object :place_data do
      string  :title,         required: false
      number  :rating,        required: false
      integer :reviews_count, required: false
      string  :address,       required: false
    end

    array :processed_reviews, of: ProcessedReviewSchema
  end
end
