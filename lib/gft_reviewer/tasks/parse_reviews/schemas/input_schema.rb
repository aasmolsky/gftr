# frozen_string_literal: true

require "dry/schema"

module ParseReviews
  module Schemas
    InputSchema = Dry::Schema.define do
      required(:place_id).filled(:string)
      required(:language).filled(:string)
      required(:place_data).hash do
        optional(:title).maybe(:string)
        required(:rating).filled(:float)
        required(:reviews_count).filled(:integer)
        optional(:address).maybe(:string)
      end
      required(:processed_reviews).maybe(:array)
    end
  end
end

