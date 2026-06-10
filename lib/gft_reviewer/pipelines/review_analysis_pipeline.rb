# frozen_string_literal: true

require_relative "../tasks/prepare_llm_report/task"

module GftReviewer
  class ReviewAnalysisPipeline < BasePipeline
    def call(input)
      llm_analyzed_data = AnalyzeReviews::Task.call(
        place_id:   input[:place_id],
        language:   input[:language],
        place_data: input[:place_data],
        reviews:    input[:reviews]
      )

      report_data, llm_report = PrepareLLMReport::Task.call(
        llm_data: llm_analyzed_data,
        data:     { place_id: input[:place_id], language: input[:language], place_data: input[:place_data], reviews: input[:reviews] },
        language: input[:language]
      )

      BuildReport::Task.call(data: report_data, llm_data: llm_report)
    end
  end
end
