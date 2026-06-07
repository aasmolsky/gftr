module GftReviewer
  class ReviewAnalysisPipeline < BasePipeline
    def call(input)
      scored = AnalyzeReviewsTask.call(
        place_id:   input[:place_id],
        language:   input[:language],
        place_data: input[:place_data],
        reviews:    input[:reviews]
      )

      BuildReportTask.call(analysis_result: scored)
    end
  end
end


