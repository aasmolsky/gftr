# frozen_string_literal: true

require "dry/schema"

module BuildReport
  module Schemas
    DataSchema = Dry::Schema.define do
      required(:place_id).filled(:string)
      required(:language).filled(:string)
      required(:place_data).hash do
        required(:title).filled(:string)
        required(:rating).filled(:float)
        required(:reviews_count).filled(:integer)
        required(:address).filled(:string)
      end
      required(:declared_rating).maybe(:float)
      required(:manipulation_assessment).filled(:string)
      required(:authenticity_score).filled(:integer)
      required(:real_only_average_rating).filled(:float)
      required(:estimated_rating).filled(:float)
      required(:analyzed_count).filled(:integer)
      required(:fake_count).filled(:integer)
      required(:real_count).filled(:integer)
      required(:uncertain_count).filled(:integer)
      required(:signal_summary).filled(:hash)
      required(:category_stats).hash do
        required(:positive).hash do
          required(:total).filled(:integer)
          required(:real).filled(:integer)
          required(:uncertain).filled(:integer)
          required(:fake).filled(:integer)
          required(:genuine_percent).filled(:integer)
          required(:share_percent).filled(:integer)
          required(:avg_rating).filled(:float)
          required(:manipulation_signals).filled(:integer)
          required(:authenticity_signals).filled(:integer)
          required(:suspicious_reviews).array(:hash) do
            required(:review_id).filled(:string)
            required(:author_name).maybe(:string)
            required(:rating).filled(:integer)
            required(:snippet).maybe(:string)
            required(:label).filled(:string)
            required(:computed_score).maybe(:integer)
            required(:score_breakdown).filled(:hash)
            required(:display_signals).array(:hash) do
              required(:key).filled(:string)
              required(:text).filled(:string)
              required(:kind).filled(:string)
            end
          end
        end

        required(:neutral).hash do
          required(:total).filled(:integer)
          required(:real).filled(:integer)
          required(:uncertain).filled(:integer)
          required(:fake).filled(:integer)
          required(:genuine_percent).filled(:integer)
          required(:share_percent).filled(:integer)
          required(:avg_rating).filled(:float)
          required(:manipulation_signals).filled(:integer)
          required(:authenticity_signals).filled(:integer)
          required(:suspicious_reviews).array(:hash) do
            required(:review_id).filled(:string)
            required(:author_name).maybe(:string)
            required(:rating).filled(:integer)
            required(:snippet).maybe(:string)
            required(:label).filled(:string)
            required(:computed_score).maybe(:integer)
            required(:score_breakdown).filled(:hash)
            required(:display_signals).array(:hash) do
              required(:key).filled(:string)
              required(:text).filled(:string)
              required(:kind).filled(:string)
            end
          end
        end

        required(:negative).hash do
          required(:total).filled(:integer)
          required(:real).filled(:integer)
          required(:uncertain).filled(:integer)
          required(:fake).filled(:integer)
          required(:genuine_percent).filled(:integer)
          required(:share_percent).filled(:integer)
          required(:avg_rating).filled(:float)
          required(:manipulation_signals).filled(:integer)
          required(:authenticity_signals).filled(:integer)
          required(:suspicious_reviews).array(:hash) do
            required(:review_id).filled(:string)
            required(:author_name).maybe(:string)
            required(:rating).filled(:integer)
            required(:snippet).maybe(:string)
            required(:label).filled(:string)
            required(:computed_score).maybe(:integer)
            required(:score_breakdown).filled(:hash)
            required(:display_signals).array(:hash) do
              required(:key).filled(:string)
              required(:text).filled(:string)
              required(:kind).filled(:string)
            end
          end
        end
      end
    end
  end
end
