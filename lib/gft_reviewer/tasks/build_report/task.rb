# frozen_string_literal: true

module BuildReport
  class Task < BaseTask
    schema do
      llm false

      param :data,     type: Hash,   required: true
      param :llm_data, type: String, required: true

      run :report do
        input   type: Hash
        returns :report, type: Hash
      end

      output Hash
    end
  end
end
