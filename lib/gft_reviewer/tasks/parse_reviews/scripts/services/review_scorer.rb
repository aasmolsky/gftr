# frozen_string_literal: true

require_relative 'constants'

module ParseReviews
  class ReviewScorer
    def initialize(review)
      @review = review
    end

    def call
      breakdown = score_breakdown

      return review.merge(computed_score: nil, label: 'fake', score_breakdown: breakdown) if forced_fake?(breakdown)

      total = score_total(breakdown)

      review.merge(computed_score: total, label: label_for(total), score_breakdown: breakdown)
    end

    private

    attr_reader :review

    def score_breakdown
      raw = review[:score_breakdown] || []
      case raw
      when Hash  then raw
      when Array then raw.each_with_object({}) { |signal, h| h[signal[:key]] = signal[:value] }
      else            {}
      end
    end

    def forced_fake?(breakdown)
      review[:score].nil? && breakdown.empty?
    end

    def score_total(breakdown)
      fake_values = breakdown.values.select { |value| value.to_i.positive? }
      real_values = breakdown.values.select { |value| value.to_i.negative? }

      fake_score = weighted_sum(fake_values)
      real_score = weighted_sum(real_values)

      (fake_score + real_score).round
    end

    def weighted_sum(values)
      values.sum(&:to_i) * coefficient(values.size)
    end

    def coefficient(size)
      return 2.0 if size >= 3
      return 1.5 if size == 2

      1.0
    end

    def label_for(total)
      return 'fake' if total > FAKE_THRESHOLD
      return 'uncertain' if total >= UNCERTAIN_THRESHOLD

      'real'
    end
  end
end
