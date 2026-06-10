# frozen_string_literal: true

require "ruby_llm/schema"

module AnalyzeReviews
  module LLMSchemas
    class ScoreSignalSchema < RubyLLM::Schema
      string  :key
      integer :value
    end

    class ProcessedReviewSchema < RubyLLM::Schema
      string  :review_id
      integer :rating
      string  :author_name

      array :score_breakdown, of: ScoreSignalSchema
    end

    class OutputSchema < RubyLLM::Schema
      array :processed_reviews, of: ProcessedReviewSchema
    end
  end
end
