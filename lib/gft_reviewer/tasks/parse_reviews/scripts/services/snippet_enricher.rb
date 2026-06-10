# frozen_string_literal: true

module ParseReviews
  class SnippetEnricher
    def initialize(processed_reviews, source_reviews)
      @processed_reviews = Array(processed_reviews)
      @source_reviews    = Array(source_reviews)
    end

    def call
      return processed_reviews if source_reviews.empty?

      snippets_by_id = source_reviews.each_with_object({}) do |review, lookup|
        id = review[:review_id] || review["review_id"]
        next if id.nil? || id.to_s.empty?

        snippet = review[:snippet] || review["snippet"]
        lookup[id] = snippet if snippet && !snippet.to_s.empty?
      end

      processed_reviews.map do |review|
        id = review[:review_id] || review["review_id"]
        existing = review[:snippet] || review["snippet"]
        next review if existing && !existing.to_s.empty?

        snippet = snippets_by_id[id]
        snippet ? review.merge(snippet: snippet) : review
      end
    end

    private

    attr_reader :processed_reviews, :source_reviews
  end
end
