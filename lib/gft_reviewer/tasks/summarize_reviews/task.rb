# frozen_string_literal: true

module SummarizeReviews
  class Task < BaseTask
    schema do
      param :language, type: String, required: true
      param :data, type: Hash, required: true do
        required(:fake_count).filled(:integer)
        required(:uncertain_count).filled(:integer)
        required(:real_count).filled(:integer)
        required(:manipulation_assessment).filled(:string)
        required(:category_stats).filled(:hash)
        required(:signal_summary).filled(:hash)
      end

      output :text
    end
  end
end
