# frozen_string_literal: true

module ParseReviews
  class Task < BaseTask
    schema do
      llm false

      param :llm_response, type: String, required: true

      run :parse do
        input type: String
        returns :parsed, type: Hash
      end
    end
  end
end
