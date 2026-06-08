# frozen_string_literal: true

module BuildReport
  class Task < BaseTask
    schema do
      llm false

      param :data,     type: Hash,   required: true
      param :llm_data, type: String, required: true

      run :report do
        input Hash
        returns do
          report Hash
        end
      end
    end
  end
end
