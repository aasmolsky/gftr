# frozen_string_literal: true

require "dry/schema"

module BuildReport
  module Schemas
    ReportInputSchema = Dry::Schema.define do
      required(:llm_data).filled(:string)
      required(:data).filled(:hash)
    end
  end
end




