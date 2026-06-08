# frozen_string_literal: true

# Orchestrates a single review-analysis request end-to-end.
#
# Usage:
#   result = ReviewQueryService.call(query_text: "ChIJ…", language: "en")
#   result.ok?         # => true / false
#   result.response_text
#   result.request_attrs  # ready to pass to Request.create
#
class ReviewQueryService
  # Lightweight value object returned to the controller.
  class Result
    attr_reader :response_text, :request_attrs

    def initialize(response_text:, request_attrs:, ok:)
      @response_text = response_text
      @request_attrs = request_attrs
      @ok = ok
    end

    def ok? = @ok
    def not_found? = !@ok
  end

  def self.call(...)
    new(...).call
  end

  def initialize(query_text:, language:)
    @query_text = query_text
    @language   = language
  end

  def call
    return not_found(hint_message) unless review_query?

    place_id = resolve_place_id
    return not_found("Could not find place for: '#{search_term}'") unless place_id

    serp_result = SerpApiReviewsService.new.fetch_reviews(place_id, hl: language)
    return not_found("Error fetching reviews: #{serp_result[:error]}") if serp_result[:error]

    analysis      = FraiReviewsAnalysisService.new.call(place_id: place_id, language: language, serp_result: serp_result)
    response_text = analysis.delete(:response_text)

    Result.new(
      response_text: response_text,
      request_attrs: analysis.merge(place_id: place_id, language: language),
      ok: true
    )
  end

  private

  attr_reader :query_text, :language

  def review_query?
    query_text.downcase.match?(/reviews for|отзывы для/) ||
      (query_text.start_with?("ChI") && query_text.length > 20)
  end

  def search_term
    @search_term ||= query_text.gsub(/reviews for|отзывы для/i, "").strip
  end

  def resolve_place_id
    if search_term.start_with?("ChI") && search_term.length > 20
      search_term
    else
      SerpApiReviewsService.new.find_place_id(search_term)
    end
  end

  def not_found(message)
    Result.new(response_text: message, request_attrs: {}, ok: false)
  end

  def hint_message
    "You asked: '#{query_text}'. To get reviews, write 'reviews for [PLACE_ID or NAME]'"
  end
end
