# frozen_string_literal: true

require_relative "schemas/input_schema"
require_relative "schemas/data_schema"
require_relative "schemas/report_schema"

module BuildReport
  class Task < BaseTask
    schema do
      llm false

      param :data, type: Hash, validate: BuildReport::Schemas::DataSchema
      param :llm_data, type: String, required: true

      directive :task do
        run :report do
          input type: Hash, validate: BuildReport::Schemas::ReportInputSchema
          returns :report, validate: BuildReport::Schemas::ReportSchema
        end
      end

      output Hash
    end
  end
end
