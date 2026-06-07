require_relative "../base_task"

class AnalyzeReviewsTask < BaseTask
  directive :main do
    params do
      required :place_id, String
      required :language, String
      required :place_data, Hash
      required :reviews, Array
      optional :max_groups, Integer, default: 5
    end
  end
end


