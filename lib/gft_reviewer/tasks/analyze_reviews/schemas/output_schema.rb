# frozen_string_literal: true

require "ruby_llm/schema"

module AnalyzeReviews
  class ScoreSignalSchema < RubyLLM::Schema
    string  :key
    integer :value
  end

  class ProcessedReviewSchema < RubyLLM::Schema
    string  :review_id
    integer :rating
    string  :author_name

    array :score_breakdown, of: AnalyzeReviews::ScoreSignalSchema
  end

  class OutputSchema < RubyLLM::Schema
    string :place_id
    string :language

    object :place_data do
      string  :title
      number  :rating
      integer :reviews_count
      string  :address
    end

    array :processed_reviews, of: AnalyzeReviews::ProcessedReviewSchema
  end
end
