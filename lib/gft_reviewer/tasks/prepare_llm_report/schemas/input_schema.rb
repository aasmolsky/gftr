# frozen_string_literal: true

require "dry/schema"

module PrepareLLMReport
  module Schemas
    InputSchema = Dry::Schema.define do
      required(:processed_reviews).filled(:array)
    end
  end
end

