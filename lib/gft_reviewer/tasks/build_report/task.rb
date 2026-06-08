class BuildReportTask < BaseTask
  schema do
    param :analysis_result, type: Hash,   required: true
    param :language,        type: String, required: true
    run :process_reviews do
      input Hash
      returns do
        review_report Hash
      end
    end
  end
end
