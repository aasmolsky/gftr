require "time"

class FraiReviewsAnalysisService
  def call(place_id:, language:, serp_result:)
    payload = build_payload(place_id: place_id, language: language, serp_result: serp_result)

    raw_result = GftReviewer::Application.call(
      place_id:   payload[:place_id],
      language:   payload[:language],
      place_data: payload[:place_data],
      reviews:    payload[:reviews],
      max_groups: 5
    )

    frai_result = normalize_result(raw_result)

    {
      analysis_status: "done",
      analysis_error: nil,
      analyzed_at: Time.current,
      llm_provider: ENV["LLM_PROVIDER"],
      llm_model: ENV["LLM_MODEL"],
      place_data_json: payload[:place_data],
      serp_reviews_json: payload[:reviews],
      frai_result_json: frai_result
    }
  rescue StandardError => e
    {
      analysis_status: "failed",
      analysis_error: e.message,
      analyzed_at: Time.current,
      llm_provider: ENV["LLM_PROVIDER"],
      llm_model: ENV["LLM_MODEL"],
      place_data_json: payload&.fetch(:place_data, {}),
      serp_reviews_json: payload&.fetch(:reviews, []),
      frai_result_json: {
        error: {
          code: "ANALYSIS_FAILED",
          message: e.message
        },
        language: payload&.fetch(:language, language),
        groups: []
      }
    }
  end

  private

  def build_payload(place_id:, language:, serp_result:)
    reviews = Array(serp_result[:reviews]).map { |review| normalize_review(review) }

    {
      place_id: place_id,
      language: language,
      place_data: {
        title: serp_result[:title],
        rating: serp_result[:rating],
        reviews_count: serp_result[:reviews_count],
        address: serp_result[:address]
      }.compact,
      reviews: reviews
    }
  end

  def normalize_review(review)
    created_at = review[:iso_date]
    edited_at = review[:iso_date_of_last_edit]

    {
      review_id: review[:review_id],
      position: review[:position],
      rating: review[:rating],
      snippet: review[:snippet],
      author_name: review.dig(:user, :name),
      author_id: review.dig(:user, :contributor_id),
      author_reviews_count: review.dig(:user, :reviews),
      author_photos_count: review.dig(:user, :photos),
      is_local_guide: review.dig(:user, :local_guide),
      review_created_at: created_at,
      review_last_edited_at: edited_at,
      was_edited: edited_at.present? && created_at.present? && edited_at != created_at,
      edit_delay_hours: edit_delay_hours(created_at, edited_at),
      likes: review[:likes] || 0
    }.compact
  end

  def edit_delay_hours(created_at, edited_at)
    return 0.0 if created_at.blank? || edited_at.blank? || created_at == edited_at

    ((Time.iso8601(edited_at) - Time.iso8601(created_at)) / 3600.0).round(2)
  rescue StandardError
    0.0
  end

  def normalize_result(raw_result)
    result = if raw_result.is_a?(Hash)
      raw_result
    elsif raw_result.respond_to?(:to_h)
      raw_result.to_h
    else
      JSON.parse(raw_result.to_s)
    end

    normalized = result.respond_to?(:deep_symbolize_keys) ? result.deep_symbolize_keys : result
    normalized[:groups] = Array(normalized[:groups])
    normalized[:calculated_rating] = normalized[:calculated_rating].to_f if normalized[:calculated_rating]
    normalized[:analyzed_ratings_count] = normalized[:analyzed_ratings_count].to_i if normalized[:analyzed_ratings_count]
    normalized[:groups] = normalized[:groups].map do |group|
      group = group.respond_to?(:deep_symbolize_keys) ? group.deep_symbolize_keys : group
      group[:examples] = Array(group[:examples])
      group[:share_percent] = group[:share_percent].to_i if group[:share_percent]
      group
    end
    normalized
  rescue JSON::ParserError, TypeError
    {
      error: {
        code: "INVALID_FRAI_RESPONSE",
        message: raw_result.to_s
      }
    }
  end
end

