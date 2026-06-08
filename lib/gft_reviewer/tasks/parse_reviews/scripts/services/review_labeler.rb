# frozen_string_literal: true

require_relative 'review_scorer'

module ParseReviews
  class ReviewLabeler
    def initialize(reviews)
      @reviews = reviews
    end

    def call
      reviews.map { |review| ReviewScorer.new(review).call }
    end

    private

    attr_reader :reviews
  end
end
