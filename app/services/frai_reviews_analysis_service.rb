require "time"

class FraiReviewsAnalysisService
  def call(place_id:, language:, serp_result:)
    payload = build_payload(place_id: place_id, language: language, serp_result: serp_result)

    raw_result = GftReviewer::Application.call(
      place_id:   payload[:place_id],
      language:   payload[:language],
      place_data: payload[:place_data],
      reviews:    payload[:reviews]
    )

    frai_result = normalize_result(raw_result)
    # analyzed_ratings_count comes from the script (actual processed), not input size

    {
      analysis_status: "done",
      analysis_error:  nil,
      analyzed_at:     Time.current,
      llm_provider:    ENV["LLM_PROVIDER"],
      llm_model:       ENV["LLM_MODEL"],
      place_data_json:    payload[:place_data],
      serp_reviews_json:  payload[:reviews],
      frai_result_json:   frai_result
    }
  rescue StandardError => e
    {
      analysis_status: "failed",
      analysis_error:  e.message,
      analyzed_at:     Time.current,
      llm_provider:    ENV["LLM_PROVIDER"],
      llm_model:       ENV["LLM_MODEL"],
      place_data_json:   payload&.fetch(:place_data, {}),
      serp_reviews_json: payload&.fetch(:reviews, []),
      frai_result_json: {
        error: { code: "ANALYSIS_FAILED", message: e.message },
        analyzed_ratings_count: 0,
        fake_count: 0, real_count: 0, uncertain_count: 0,
        authenticity_score: 0,
        calculated_rating: 0.0,
        real_only_average_rating: 0.0,
        manipulation_assessment: "mixed",
        rating_categories: empty_categories,
        signal_summary: {},
        key_conclusions: [],
        language: language
      }
    }
  end

  private

  # ---------------------------------------------------------------------------
  # Build payload — normalize SERP reviews into the schema Task 1 expects
  # ---------------------------------------------------------------------------
  MAX_REVIEWS = 30

  # ...existing code...

  def build_payload(place_id:, language:, serp_result:)
    reviews = Array(serp_result[:reviews]).first(MAX_REVIEWS).map { |r| normalize_review(r) }
    {
      place_id:   place_id,
      language:   language,
      place_data: {
        title:         serp_result[:title],
        rating:        serp_result[:rating],
        reviews_count: serp_result[:reviews_count],
        address:       serp_result[:address]
      }.compact,
      reviews: reviews
    }
  end

  def normalize_review(review)
    created_at = review[:iso_date]
    edited_at  = review[:iso_date_of_last_edit]
    snippet    = review[:snippet].to_s
    response   = review[:response]

    {
      review_id:             review[:review_id],
      position:              review[:position],
      rating:                review[:rating],
      snippet:               snippet,
      snippet_length:        snippet.length,
      author_name:           review.dig(:user, :name),
      author_id:             review.dig(:user, :contributor_id),
      author_reviews_count:  review.dig(:user, :reviews),
      author_photos_count:   review.dig(:user, :photos),
      is_local_guide:        review.dig(:user, :local_guide),
      images_count:          Array(review[:images]).size,
      response_present:      response.present?,
      response_length:       response.is_a?(Hash) ? response[:snippet].to_s.length : response.to_s.length,
      review_created_at:     created_at,
      review_last_edited_at: edited_at,
      was_edited:            edited_at.present? && created_at.present? && edited_at != created_at,
      edit_delay_hours:      edit_delay_hours(created_at, edited_at),
      likes:                 review[:likes] || 0
    }.compact
  end

  def edit_delay_hours(created_at, edited_at)
    return 0.0 if created_at.blank? || edited_at.blank? || created_at == edited_at
    ((Time.iso8601(edited_at) - Time.iso8601(created_at)) / 3600.0).round(2)
  rescue StandardError
    0.0
  end

  # ---------------------------------------------------------------------------
  # Normalize pipeline output (review_report) → frai_result_json the UI reads
  # ---------------------------------------------------------------------------
  def normalize_result(raw_result)
    r = case raw_result
        when Hash then raw_result.respond_to?(:deep_symbolize_keys) ? raw_result.deep_symbolize_keys : raw_result
        else
          cleaned = raw_result.to_s.gsub(/\A\s*```(?:json)?\s*/i, "").gsub(/\s*```\s*\z/, "").strip
          JSON.parse(cleaned, symbolize_names: true)
        end

    total           = r[:analyzed_count].to_i
    fake_count      = r[:fake_count].to_i
    real_count      = r[:real_count].to_i
    uncertain_count = r[:uncertain_count].to_i

    {
      manipulation_assessment:  derive_assessment(fake_count, real_count, total),
      authenticity_score:       total.positive? ? (real_count.to_f / total * 100).round : 0,
      analyzed_ratings_count:   total,
      fake_count:               fake_count,
      real_count:               real_count,
      uncertain_count:          uncertain_count,
      calculated_rating:        r[:declared_rating].to_f,
      real_only_average_rating: r[:real_only_average_rating].to_f,
      rating_categories:        map_categories(r[:category_stats], total),
      signal_summary:           r[:signal_summary] || {},
      key_conclusions:          Array(r[:key_tendencies]),
      language:                 r[:language].to_s
    }
  rescue JSON::ParserError, TypeError => e
    raise "Pipeline returned non-parseable response: #{e.message}"
  end

  def derive_assessment(fake_count, real_count, total)
    return "mixed" unless total.positive?
    if fake_count.to_f / total > 0.5
      "likely_fake"
    elsif real_count.to_f / total > 0.8
      "likely_real"
    else
      "mixed"
    end
  end

  def map_categories(category_stats, total)
    cs = (category_stats || {}).respond_to?(:deep_symbolize_keys) ? category_stats.deep_symbolize_keys : (category_stats || {})

    %i[positive neutral negative].each_with_object({}) do |key, memo|
      cat   = (cs[key] || {}).respond_to?(:deep_symbolize_keys) ? cs[key].deep_symbolize_keys : (cs[key] || {})
      count = cat[:total].to_i
      memo[key] = {
        count:           count,
        real:            cat[:real].to_i,
        fake:            cat[:fake].to_i,
        uncertain:       cat[:uncertain].to_i,
        genuine_percent: count.positive? ? (cat[:real].to_i * 100.0 / count).round : 0,
        share_percent:   total.positive? ? (count * 100.0 / total).round : 0,
        avg_rating:      cat[:avg_rating].to_f
      }
    end
  end

  def empty_categories
    %i[positive neutral negative].each_with_object({}) do |k, h|
      h[k] = { count: 0, real: 0, fake: 0, uncertain: 0, genuine_percent: 0, share_percent: 0, avg_rating: 0.0 }
    end
  end
end
