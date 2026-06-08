#!/usr/bin/env ruby
# frozen_string_literal: true
# desc: Processes scored reviews — assigns labels, computes real-only rating, aggregates signals

require "json"

payload = JSON.parse($stdin.read, symbolize_names: true)

# build_report receives a single input hash: { analysis_result: ..., language: ... }
data = payload[:input] || payload
data = data[:analysis_result] if data.is_a?(Hash) && data[:analysis_result].is_a?(Hash)

place_id   = data[:place_id].to_s
language   = (payload.dig(:input, :language) || data[:language]).to_s
place_data = data[:place_data] || {}
reviews    = Array(data[:processed_reviews])

# ---------------------------------------------------------------------------
# Verdict thresholds
# ---------------------------------------------------------------------------
FAKE_THRESHOLD      = 40
UNCERTAIN_THRESHOLD = 20

# ---------------------------------------------------------------------------
# Step 1: compute total_score per review, assign label
# ---------------------------------------------------------------------------
labeled = reviews.map do |review|
  breakdown = (review[:score_breakdown] || {})

  # Non-negotiable override: score is null AND breakdown is empty
  if review[:score].nil? && breakdown.empty?
    review.merge(computed_score: nil, label: "fake")
  else
    fake_values = breakdown.values.select { |v| v.to_i > 0 }
    real_values = breakdown.values.select { |v| v.to_i < 0 }

    coeff = ->(n) { n >= 3 ? 2.0 : n == 2 ? 1.5 : 1.0 }

    fake_score = fake_values.sum(&:to_i) * coeff.call(fake_values.size)
    real_score = real_values.sum(&:to_i) * coeff.call(real_values.size)

    total = (fake_score + real_score).round

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
# Step 2: overall counts + real-only average rating
# ---------------------------------------------------------------------------
fake_count      = labeled.count { |r| r[:label] == "fake" }
uncertain_count = labeled.count { |r| r[:label] == "uncertain" }
real_count      = labeled.count { |r| r[:label] == "real" }

real_reviews  = labeled.select { |r| r[:label] == "real" }
real_ratings  = real_reviews.map { |r| r[:rating].to_f }.reject(&:zero?)
real_only_avg = real_ratings.any? ? (real_ratings.sum / real_ratings.size).round(2) : 0.0

# Estimated rating: fakes treated as 2.5★ penalty
total_count = labeled.size
estimated_rating = if total_count.positive? && real_only_avg > 0
  ((real_only_avg * real_count + 2.5 * fake_count) / total_count).round(2)
else
  0.0
end

# ---------------------------------------------------------------------------
# Step 3: category stats (positive 4-5★, neutral 3★, negative 1-2★)
# ---------------------------------------------------------------------------
FAKE_SIGNAL_KEYS = %w[
  THIN_ACCOUNT_0 THIN_ACCOUNT_1 SHORT_TEXT_EXTREME SHORT_TEXT
  BURST_AFTER_NEGATIVE FIVE_STAR_EMPTY SURNAME_REPEAT GENERIC_TEXT
  SUSPICIOUS_NEGATIVE MARKETING_TONE EMOJI_SPAM TEMPLATE_CLONE
  ALL_POSITIVE REPEATABLE_PLUSES_2 REPEATABLE_PLUSES_3 BUSINESS_NAME_DROP
].freeze

REAL_SIGNAL_KEYS = %w[
  EDITED_REVIEW HAS_PHOTOS EXPERIENCED_AUTHOR_5 EXPERIENCED_AUTHOR_10
  ACTIVE_PROFILE LONG_TEXT SPECIFIC_DETAILS BALANCED_TONE NATURAL_LANGUAGE
  LOCAL_GUIDE OWNER_RESPONDED HELPFUL_VOTES
].freeze

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
  ratings = bucket.map { |r| r[:rating].to_f }.reject(&:zero?)

  manip_signals = 0
  auth_signals  = 0
  bucket.each do |r|
    (r[:score_breakdown] || {}).each_key do |k|
      if FAKE_SIGNAL_KEYS.include?(k.to_s)
        manip_signals += 1
      elsif REAL_SIGNAL_KEYS.include?(k.to_s)
        auth_signals  += 1
      end
    end
  end

  # Top-3 most suspicious: fake first (by computed_score desc), then uncertain
  suspicious = bucket
    .select  { |r| %w[fake uncertain].include?(r[:label]) }
    .sort_by { |r| [r[:label] == "fake" ? 0 : 1, -(r[:computed_score] || 0)] }
    .first(3)
    .map { |r|
      {
        review_id:      r[:review_id],
        author_name:    r[:author_name],
        rating:         r[:rating],
        snippet:        r[:snippet].to_s[0, 200],
        label:          r[:label],
        computed_score: r[:computed_score],
        score_breakdown: r[:score_breakdown] || {}
      }
    }

  {
    total:                 bucket.size,
    real:                  bucket.count { |r| r[:label] == "real" },
    uncertain:             bucket.count { |r| r[:label] == "uncertain" },
    fake:                  bucket.count { |r| r[:label] == "fake" },
    avg_rating:            ratings.any? ? (ratings.sum / ratings.size).round(1) : 0.0,
    manipulation_signals:  manip_signals,
    authenticity_signals:  auth_signals,
    suspicious_reviews:    suspicious
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
# Output
# ---------------------------------------------------------------------------
review_report = {
  place_id:                 place_id,
  language:                 language,
  place_data:               place_data,
  declared_rating:          place_data[:rating],
  real_only_average_rating: real_only_avg,
  estimated_rating:         estimated_rating,
  analyzed_count:           labeled.size,
  fake_count:               fake_count,
  uncertain_count:          uncertain_count,
  real_count:               real_count,
  category_stats:           category_stats,
  signal_summary:           signal_summary
}

puts JSON.generate(review_report: review_report)

# ---------------------------------------------------------------------------
# Debug log
# ---------------------------------------------------------------------------
# begin
#   log_path = File.expand_path("../../../../../log/process_reviews.log", __dir__)
#   File.open(log_path, "a") do |f|
#     f.puts "\n=== #{Time.now} ==="
#    f.puts "--- INPUT reviews (#{reviews.size}) ---"
#    f.puts JSON.pretty_generate(reviews)
#    f.puts "--- OUTPUT review_report ---"
#    f.puts JSON.pretty_generate(review_report)
# end
# rescue => e
#   $stderr.puts "process_reviews log failed: #{e.message}"
# end
