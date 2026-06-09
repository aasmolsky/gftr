# frozen_string_literal: true

module SummarizeReviews
  class Task < BaseTask
    schema do
      param :data, type: Hash, required: true
      param :language, type: String, required: true

      output :text
    end
  end
end
