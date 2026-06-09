# frozen_string_literal: true

module ParseReviews
  class Task < BaseTask
    schema do
      llm false

      param :llm_response, type: Hash, required: true

      run :parse do
        input   type: Hash
        returns :parsed, type: Hash
      end

      output Hash
    end
  end
end
