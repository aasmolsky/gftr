module GftReviewer
  class ReviewAnalysisPipeline < BasePipeline
    def call(input)
      scored = AnalyzeReviewsTask.call(
        place_id:   input[:place_id],
        language:   input[:language],
        place_data: input[:place_data],
        reviews:    input[:reviews]
      )

      scored_hash = scored.is_a?(Hash) ? scored : JSON.parse(strip_fences(scored.to_s), symbolize_names: true)

      BuildReportTask.call(analysis_result: scored_hash, language: input[:language])
    end

    private

    def strip_fences(str)
      str.gsub(/\A\s*```(?:json)?\s*/i, "").gsub(/\s*```\s*\z/, "").strip
    end
  end
end


