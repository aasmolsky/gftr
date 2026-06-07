#!/usr/bin/env ruby
# frozen_string_literal: true
# desc: Processes scored reviews — assigns labels, computes real-only rating, aggregates signals

require "json"

payload = JSON.parse($stdin.read, symbolize_names: true)

# analysis_result is the direct output of analyze_reviews task
data = payload[:input] || payload

place_id   = data[:place_id].to_s
language   = data[:language].to_s
place_data = data[:place_data] || {}
reviews    = Array(data[:processed_reviews])

# ---------------------------------------------------------------------------
# Verdict thresholds
# ---------------------------------------------------------------------------
FAKE_THRESHOLD      = 50
UNCERTAIN_THRESHOLD = 20

# ---------------------------------------------------------------------------
# Step 1: compute total_score per review, assign label
# ---------------------------------------------------------------------------
labeled = reviews.map do |review|
  # score: null means non-negotiable override from Task 1 → always fake
  if review[:score].nil?
    review.merge(computed_score: nil, label: "fake")
  else
    total = review[:score].to_i

    label = if total > FAKE_THRESHOLD
      "fake"
    elsif total >= UNCERTAIN_THRESHOLD
      "uncertain"
    else
      "real"
    end

    review.merge(computed_score: total, label: label)
  end
end

# ---------------------------------------------------------------------------
# Step 2: real-only average rating
# ---------------------------------------------------------------------------
real_reviews  = labeled.select { |r| r[:label] == "real" }
real_ratings  = real_reviews.map { |r| r[:rating].to_f }.reject(&:zero?)
real_only_avg = real_ratings.any? ? (real_ratings.sum / real_ratings.size).round(2) : 0.0

# ---------------------------------------------------------------------------
# Step 3: category stats (positive 4-5★, neutral 3★, negative 1-2★)
# ---------------------------------------------------------------------------
buckets = { positive: [], neutral: [], negative: [] }

labeled.each do |r|
  key = case r[:rating].to_i
        when 4, 5 then :positive
        when 3    then :neutral
        else           :negative
        end
  buckets[key] << r
end

category_stats = buckets.transform_values do |bucket|
  {
    total:     bucket.size,
    real:      bucket.count { |r| r[:label] == "real" },
    uncertain: bucket.count { |r| r[:label] == "uncertain" },
    fake:      bucket.count { |r| r[:label] == "fake" }
  }
end

# ---------------------------------------------------------------------------
# Step 4: signal summary — how many reviews triggered each criterion key
# ---------------------------------------------------------------------------
signal_counts = Hash.new(0)

labeled.each do |r|
  (r[:score_breakdown] || {}).each_key do |key|
    signal_counts[key.to_s] += 1
  end
end

signal_summary = signal_counts.sort_by { |_, count| -count }.to_h

# ---------------------------------------------------------------------------
# Step 5: overall counts
# ---------------------------------------------------------------------------
fake_count      = labeled.count { |r| r[:label] == "fake" }
uncertain_count = labeled.count { |r| r[:label] == "uncertain" }
real_count      = labeled.count { |r| r[:label] == "real" }

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------
review_report = {
  place_id:                 place_id,
  language:                 language,
  place_data:               place_data,
  declared_rating:          place_data[:rating],
  real_only_average_rating: real_only_avg,
  analyzed_count:           labeled.size,
  fake_count:               fake_count,
  uncertain_count:          uncertain_count,
  real_count:               real_count,
  category_stats:           category_stats,
  signal_summary:           signal_summary
}

puts JSON.generate(review_report: review_report)
