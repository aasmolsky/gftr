# frozen_string_literal: true

require_relative "schemas/input_schema"
require_relative "schemas/prepared_data_schema"

module PrepareLLMReport
  class Task < BaseTask
    schema do
      param :language, type: String, required: true
      param :data, type: Hash, required: true do
        required(:place_data).filled(:hash)
        required(:reviews).maybe(:array)
      end
      param :llm_data, type: Hash, validate: PrepareLLMReport::Schemas::InputSchema

      run :prepare_data do
        input type: Hash do
          required(:llm_data).filled(:hash)
          required(:data).filled(:hash)
        end
        returns :prepared_data, validate: PrepareLLMReport::Schemas::PreparedDataSchema
      end

      output :text
    end

    def call(input)
      llm_report = super
      [script_results[:prepared_data], llm_report]
    end
  end
end
