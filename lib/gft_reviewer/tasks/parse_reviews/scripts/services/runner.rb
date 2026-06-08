# frozen_string_literal: true

require_relative 'input_normalizer'
require_relative 'review_labeler'
require_relative 'report_builder'

module ParseReviews
  class Runner
    def self.call(payload)
      new(payload).call
    end

    def initialize(payload)
      @payload = payload
    end

    def call
      input = InputNormalizer.new(payload).call
      labeled_reviews = ReviewLabeler.new(input[:reviews]).call

      ReportBuilder.new(input, labeled_reviews).call
    end

    private

    attr_reader :payload
  end
end
