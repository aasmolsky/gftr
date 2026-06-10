# frozen_string_literal: true

require_relative "../tasks/summarize_reviews/task"

module GftReviewer
  class ReviewAnalysisPipeline < BasePipeline
    def call(input)
      llm_analyzed_data = AnalyzeReviews::Task.call(
        place_id:   input[:place_id],
        language:   input[:language],
        place_data: input[:place_data],
        reviews:    input[:reviews]
      )

      parsed_data = ParseReviews::Task.call(
        llm_response:   llm_analyzed_data,
        source_reviews: input[:reviews],
        place_data:     input[:place_data]
      )

      interpretation = SummarizeReviews::Task.call(
        data:     parsed_data,
        language: input[:language]
      )

      BuildReport::Task.call(data: parsed_data, llm_data: interpretation)
    end
  end
end
