#!/usr/bin/env ruby
# frozen_string_literal: true
# desc: Summarizes fraud-relevant signals from reviews for the LLM prompt

require "json"

payload = JSON.parse($stdin.read, symbolize_names: true)
reviews = Array(payload[:input] || payload[:reviews])

ratings               = reviews.map { |r| r[:rating].to_f }.compact
author_reviews_counts = reviews.map { |r| r[:author_reviews_count].to_i }
snippet_lengths       = reviews.map { |r| r[:snippet].to_s.length }

positive_reviews = reviews.select { |r| r[:rating].to_i >= 4 }
neutral_reviews  = reviews.select { |r| r[:rating].to_i == 3 }
negative_reviews = reviews.select { |r| r[:rating].to_i <= 2 }

# --- Temporal burst detection ---------------------------------------------------
# Reviews are ordered by position (most recent first from SERP API).
# After each 1-2★ review, any 5★ review in the next 5 positions is a burst candidate.
sorted = reviews.sort_by { |r| r[:position].to_i }
post_negative_burst_ids = []
sorted.each_with_index do |review, idx|
  next unless review[:rating].to_i <= 2

  window = sorted[idx + 1, 5] || []
  window.each do |r|
    post_negative_burst_ids << r[:review_id].to_s if r[:rating].to_i == 5 && r[:review_id]
  end
end
post_negative_burst_ids.uniq!
post_negative_fivestar_count = post_negative_burst_ids.size

# --- Repeated surname pattern ----------------------------------------------------
last_names = reviews.filter_map { |r| r[:author_name].to_s.split.last&.downcase }
surname_freq = last_names.tally
repeated_surname_count  = surname_freq.count { |_, n| n >= 2 }
max_surname_repetitions = surname_freq.values.max || 0
top_repeated_surname    = surname_freq.max_by { |_, n| n }&.first

# --- Weak / generic content signals ---------------------------------------------
very_short_count    = reviews.count { |r| r[:snippet].to_s.strip.length < 20 }
no_specifics_count  = reviews.count { |r| r[:snippet].to_s.strip.length < 50 }
weak_author_count   = reviews.count { |r| r[:author_reviews_count].to_i <= 3 }
five_star_generic   = reviews.count { |r| r[:rating].to_i == 5 && r[:snippet].to_s.strip.length < 50 }

rating_distribution = (1..5).each_with_object({}) do |rating, memo|
  memo[rating] = reviews.count { |r| r[:rating].to_i == rating }
end

review_signals = {
  total_reviews_count:           reviews.size,
  average_rating:                ratings.any? ? (ratings.sum / ratings.size).round(2) : 0.0,
  rating_distribution:           rating_distribution,
  rating_categories: {
    positive: { count: positive_reviews.size, share_percent: reviews.any? ? ((positive_reviews.size.to_f / reviews.size) * 100).round : 0 },
    neutral:  { count: neutral_reviews.size,  share_percent: reviews.any? ? ((neutral_reviews.size.to_f  / reviews.size) * 100).round : 0 },
    negative: { count: negative_reviews.size, share_percent: reviews.any? ? ((negative_reviews.size.to_f / reviews.size) * 100).round : 0 }
  },
  # Fraud-specific signals
  post_negative_fivestar_count:  post_negative_fivestar_count,
  post_negative_burst_ids:       post_negative_burst_ids,
  repeated_surname_count:        repeated_surname_count,
  max_surname_repetitions:       max_surname_repetitions,
  top_repeated_surname:          top_repeated_surname,
  very_short_review_count:       very_short_count,
  no_specifics_review_count:     no_specifics_count,
  five_star_generic_count:       five_star_generic,
  weak_author_count:             weak_author_count,
  average_author_reviews_count:  author_reviews_counts.any? ? (author_reviews_counts.sum.to_f / author_reviews_counts.size).round(2) : 0.0,
  average_snippet_length:        snippet_lengths.any? ? (snippet_lengths.sum.to_f / snippet_lengths.size).round(2) : 0.0,
  edited_count:                  reviews.count { |r| r[:was_edited] },
  with_images_count:             reviews.count { |r| r[:images_count].to_i > 0 },
  local_guide_count:             reviews.count { |r| r[:is_local_guide] }
}

puts JSON.generate(review_signals: review_signals)
