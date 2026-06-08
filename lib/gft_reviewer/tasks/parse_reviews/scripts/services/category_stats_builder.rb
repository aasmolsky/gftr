# frozen_string_literal: true

require_relative 'constants'

module ParseReviews
  class CategoryStatsBuilder
    def initialize(labeled_reviews)
      @labeled_reviews = labeled_reviews
      @total = labeled_reviews.size
    end

    def call
      bucketize.transform_values { |bucket| build_stats(bucket) }
    end

    private

    attr_reader :labeled_reviews

    def bucketize
      buckets = { positive: [], neutral: [], negative: [] }

      labeled_reviews.each do |review|
        buckets[bucket_for(review)] << review
      end

      buckets
    end

    def bucket_for(review)
      case review[:rating].to_i
      when 4, 5 then :positive
      when 3 then :neutral
      else :negative
      end
    end

    def build_stats(bucket)
      count   = bucket.size
      real    = count_label(bucket, 'real')
      ratings = bucket.map { |review| review[:rating].to_f }.reject(&:zero?)

      {
        total:                 count,
        real:                  real,
        uncertain:             count_label(bucket, 'uncertain'),
        fake:                  count_label(bucket, 'fake'),
        genuine_percent:       count.positive? ? (real * 100.0 / count).round : 0,
        share_percent:         @total.positive? ? (count * 100.0 / @total).round : 0,
        avg_rating:            ratings.any? ? (ratings.sum / ratings.size).round(1) : 0.0,
        manipulation_signals:  signal_hits(bucket, FAKE_SIGNAL_KEYS),
        authenticity_signals:  signal_hits(bucket, REAL_SIGNAL_KEYS),
        suspicious_reviews:    suspicious_reviews(bucket)
      }
    end

    def count_label(bucket, label)
      bucket.count { |review| review[:label] == label }
    end

    def signal_hits(bucket, signal_keys)
      bucket.sum do |review|
        review_breakdown = review[:score_breakdown] || {}
        review_breakdown.each_key.count { |key| signal_keys.include?(key.to_s) }
      end
    end

    def suspicious_reviews(bucket)
      bucket
        .select { |review| %w[fake uncertain].include?(review[:label]) }
        .sort_by { |review| [review[:label] == 'fake' ? 0 : 1, -(review[:computed_score] || 0)] }
        .first(3)
        .map { |review| suspicious_review_payload(review) }
    end

    def suspicious_review_payload(review)
      {
        review_id: review[:review_id],
        author_name: review[:author_name],
        rating: review[:rating],
        snippet: review[:snippet],
        label: review[:label],
        computed_score: review[:computed_score],
        score_breakdown: review[:score_breakdown] || {}
      }
    end
  end
end
