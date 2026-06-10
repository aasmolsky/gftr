# frozen_string_literal: true

require "dry/schema"

module ParseReviews
  module Schemas
    ParsedSchema = Dry::Schema.define do
      required(:place_id).filled(:string)
      required(:language).filled(:string)
      required(:place_data).filled(:hash)
      required(:declared_rating).maybe(:float)
      required(:manipulation_assessment).filled(:string)
      required(:authenticity_score).filled(:integer)
      required(:real_only_average_rating).filled(:float)
      required(:estimated_rating).filled(:float)
      required(:analyzed_count).filled(:integer)
      required(:fake_count).filled(:integer)
      required(:real_count).filled(:integer)
      required(:uncertain_count).filled(:integer)
      required(:category_stats).filled(:hash)
      required(:signal_summary).filled(:hash)
    end
  end
end

