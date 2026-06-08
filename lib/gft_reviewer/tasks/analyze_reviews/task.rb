class AnalyzeReviewsTask < BaseTask
  schema do
    param :place_id,   type: String, required: true
    param :language,   type: String, required: true
    param :place_data, type: Hash,   required: true
    param :reviews,    type: Array,  required: true
    use :review_scores
    use :review_patterns
  end
end
