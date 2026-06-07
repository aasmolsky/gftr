#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

payload = JSON.parse($stdin.read, symbolize_names: true)
reviews = Array(payload[:input] || payload[:reviews])

ratings = reviews.map { |review| review[:rating].to_f }.compact
author_reviews_counts = reviews.map { |review| review.dig(:user, :reviews).to_i }

review_stats = {
  count: reviews.size,
  average_rating: ratings.any? ? (ratings.sum / ratings.size).round(2) : 0.0,
  min_rating: ratings.min || 0.0,
  max_rating: ratings.max || 0.0,
  with_snippet_count: reviews.count { |review| review[:snippet].to_s.strip != "" },
  with_response_count: reviews.count { |review| review[:response].is_a?(Hash) || review[:response].to_s.strip != "" },
  edited_count: reviews.count do |review|
    created_at = review[:iso_date].to_s
    edited_at = review[:iso_date_of_last_edit].to_s
    edited_at != "" && created_at != "" && edited_at != created_at
  end,
  local_guide_count: reviews.count { |review| review.dig(:user, :local_guide) },
  average_author_reviews_count: author_reviews_counts.any? ? (author_reviews_counts.sum.to_f / author_reviews_counts.size).round(2) : 0.0
}

puts JSON.generate(review_stats: review_stats)

