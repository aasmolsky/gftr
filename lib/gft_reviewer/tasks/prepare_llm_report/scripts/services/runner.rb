# frozen_string_literal: true

require_relative 'input_normalizer'
require_relative 'snippet_enricher'
require_relative 'review_labeler'
require_relative 'report_builder'

module PrepareLLMReport
  class Runner
    def self.call(payload)
      new(payload).call
    end

    def initialize(payload)
      @payload = payload
    end

    def call
      input = InputNormalizer.new(payload).call
      reviews = SnippetEnricher.new(input[:reviews], input[:source_reviews]).call
      labeled_reviews = ReviewLabeler.new(reviews).call

      ReportBuilder.new(input, labeled_reviews).call
    end

    private

    attr_reader :payload
  end
end
