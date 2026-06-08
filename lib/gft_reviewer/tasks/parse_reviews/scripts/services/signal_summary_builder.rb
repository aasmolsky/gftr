# frozen_string_literal: true

module ParseReviews
  class SignalSummaryBuilder
    def initialize(labeled_reviews)
      @labeled_reviews = labeled_reviews
    end

    def call
      signal_counts.sort_by { |_, count| -count }.to_h
    end

    private

    attr_reader :labeled_reviews

    def signal_counts
      counts = Hash.new(0)

      labeled_reviews.each do |review|
        (review[:score_breakdown] || {}).each_key do |signal_key|
          counts[signal_key.to_s] += 1
        end
      end

      counts
    end
  end
end
