# frozen_string_literal: true

require_relative "schemas/input_schema"
require_relative "schemas/parsed_schema"

module ParseReviews
  class Task < BaseTask
    schema do
      llm false

      param :source_reviews, type: Array, default: []
      param :llm_response, validate: ParseReviews::Schemas::InputSchema

      run :parse do
        input type: Hash, validate: ParseReviews::Schemas::InputSchema
        returns :parsed, validate: ParseReviews::Schemas::ParsedSchema
      end

      output Hash
    end
  end
end
