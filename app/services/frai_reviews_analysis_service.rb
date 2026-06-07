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

    # All stats computed from raw data — never trust LLM arithmetic
    frai_result[:review_labels]            = enforce_deterministic_labels(frai_result[:review_labels], payload[:reviews])
    frai_result[:analyzed_ratings_count]   = payload[:reviews].size
    frai_result[:fake_count]               = frai_result[:review_labels].count { |l| l[:label] == "fake" }
    frai_result[:real_count]               = frai_result[:analyzed_ratings_count] - frai_result[:fake_count]
    frai_result[:calculated_rating]        = average_rating(payload[:reviews])
    frai_result[:real_only_average_rating] = real_only_average_rating(payload[:reviews], frai_result[:review_labels])
    frai_result[:authenticity_score]       = computed_authenticity_score(frai_result[:real_count], frai_result[:analyzed_ratings_count])
    frai_result[:rating_categories]        = category_breakdown(payload[:reviews], frai_result[:review_labels])

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
        error: { code: "ANALYSIS_FAILED", message: e.message },
        analyzed_ratings_count: 0,
        fake_count: 0,
        real_count: 0,
        authenticity_score: 0,
        calculated_rating: 0.0,
        real_only_average_rating: 0.0,
        rating_categories: empty_category_breakdown,
        key_conclusions: [],
        language: payload&.fetch(:language, language)
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
    edited_at  = review[:iso_date_of_last_edit]
    snippet    = review[:snippet].to_s
    response   = review[:response]

    {
      review_id:            review[:review_id],
      position:             review[:position],
      rating:               review[:rating],
      snippet:              snippet,
      snippet_length:       snippet.length,
      author_name:          review.dig(:user, :name),
      author_id:            review.dig(:user, :contributor_id),
      author_reviews_count: review.dig(:user, :reviews),
      author_photos_count:  review.dig(:user, :photos),
      is_local_guide:       review.dig(:user, :local_guide),
      images_count:         Array(review[:images]).size,
      response_present:     response.present?,
      response_length:      response.is_a?(Hash) ? response[:snippet].to_s.length : response.to_s.length,
      review_created_at:    created_at,
      review_last_edited_at: edited_at,
      was_edited:           edited_at.present? && created_at.present? && edited_at != created_at,
      edit_delay_hours:     edit_delay_hours(created_at, edited_at),
      likes:                review[:likes] || 0
    }.compact
  end

  def edit_delay_hours(created_at, edited_at)
    return 0.0 if created_at.blank? || edited_at.blank? || created_at == edited_at
    ((Time.iso8601(edited_at) - Time.iso8601(created_at)) / 3600.0).round(2)
  rescue StandardError
    0.0
  end

  # ---------------------------------------------------------------------------
  # Normalise raw LLM response
  # ---------------------------------------------------------------------------
  def normalize_result(raw_result)
    result = if raw_result.is_a?(Hash)
      raw_result
    elsif raw_result.respond_to?(:to_h)
      raw_result.to_h
    else
      JSON.parse(raw_result.to_s)
    end

    normalized = result.respond_to?(:deep_symbolize_keys) ? result.deep_symbolize_keys : result
    normalized[:key_conclusions] = Array(normalized[:key_conclusions] || normalized[:conclusions])
    normalized[:suspicious_patterns] = Array(normalized[:suspicious_patterns])
    normalized[:fake_signals]        = Array(normalized[:fake_signals])
    normalized[:real_signals]        = Array(normalized[:real_signals])

    normalized[:review_labels] = Array(normalized[:review_labels]).map do |label|
      label = label.respond_to?(:deep_symbolize_keys) ? label.deep_symbolize_keys : label
      label[:confidence] = label[:confidence].to_f
      label
    end

    # category_analysis narratives from LLM
    ca = normalized[:category_analysis] || {}
    ca = ca.respond_to?(:deep_symbolize_keys) ? ca.deep_symbolize_keys : ca
    normalized[:category_analysis] = %i[positive neutral negative].each_with_object({}) do |k, memo|
      block = (ca[k] || {}).respond_to?(:deep_symbolize_keys) ? (ca[k] || {}).deep_symbolize_keys : (ca[k] || {})
      memo[k] = { narrative: block[:narrative].to_s }
    end

    normalized
  rescue JSON::ParserError, TypeError
    raise "LLM returned non-JSON response. Check FRAI_ENV=#{ENV.fetch('FRAI_ENV', 'production')} and that LLM_MODEL is set."
  end

  # ---------------------------------------------------------------------------
  # Deterministic label enforcement (burst + thin account)
  # ---------------------------------------------------------------------------
  def enforce_deterministic_labels(review_labels, reviews)
    burst_ids   = post_negative_burst_ids(reviews)
    thin_ids    = thin_generic_five_star_ids(reviews)
    forced_fake = (burst_ids + thin_ids).to_set
    existing    = Array(review_labels).index_by { |l| l[:review_id].to_s }

    Array(reviews).map do |review|
      id    = review[:review_id].to_s
      label = existing[id] || { review_id: id, label: "uncertain", confidence: 0.5, reason: "" }

      if forced_fake.include?(id)
        reasons = []
        reasons << "post-negative burst: 5★ immediately after 1–2★ review" if burst_ids.include?(id)
        reasons << "thin account (≤1 review) with generic short 5★ text"   if thin_ids.include?(id)
        label.merge(label: "fake", confidence: 1.0, reason: reasons.join("; "))
      else
        label
      end
    end
  end

  def post_negative_burst_ids(reviews)
    sorted = Array(reviews).sort_by { |r| r[:position].to_i }
    ids    = []
    sorted.each_with_index do |review, idx|
      next unless review[:rating].to_i <= 2
      window = sorted[idx + 1, 5] || []
      window.each { |r| ids << r[:review_id].to_s if r[:rating].to_i == 5 && r[:review_id] }
    end
    ids.uniq
  end

  def thin_generic_five_star_ids(reviews)
    Array(reviews).filter_map do |r|
      next unless r[:rating].to_i == 5
      next unless r[:author_reviews_count].to_i <= 1
      next unless r[:snippet].to_s.strip.length < 40
      r[:review_id].to_s
    end
  end

  # ---------------------------------------------------------------------------
  # Rating & category stats — all computed from raw data
  # ---------------------------------------------------------------------------
  def average_rating(reviews)
    ratings = Array(reviews).map { |r| r[:rating].to_f }.reject(&:zero?)
    ratings.any? ? (ratings.sum / ratings.size).round(2) : 0.0
  end

  def real_only_average_rating(reviews, review_labels)
    fake_ids = Array(review_labels).select { |l| l[:label].to_s == "fake" }
                                   .map { |l| l[:review_id].to_s }.to_set
    real_ratings = Array(reviews).reject { |r| fake_ids.include?(r[:review_id].to_s) }
                                 .map { |r| r[:rating].to_f }.reject(&:zero?)
    real_ratings.any? ? (real_ratings.sum / real_ratings.size).round(2) : 0.0
  end

  def computed_authenticity_score(real_count, total)
    return 0 unless total.to_i.positive?
    (real_count.to_f / total * 100).round
  end

  # Returns per-category breakdown: { positive: { count, fake, real, genuine_percent, avg_rating }, … }
  def category_breakdown(reviews, review_labels)
    label_map = Array(review_labels).each_with_object({}) { |l, h| h[l[:review_id].to_s] = l[:label].to_s }

    buckets = {
      positive: Array(reviews).select { |r| r[:rating].to_i >= 4 },
      neutral:  Array(reviews).select { |r| r[:rating].to_i == 3 },
      negative: Array(reviews).select { |r| r[:rating].to_i <= 2 }
    }
    total = reviews.size

    buckets.transform_values do |bucket|
      fake  = bucket.count { |r| label_map[r[:review_id].to_s] == "fake" }
      real  = bucket.size - fake
      count = bucket.size
      ratings = bucket.map { |r| r[:rating].to_f }.reject(&:zero?)
      {
        count:          count,
        fake:           fake,
        real:           real,
        genuine_percent: count.positive? ? (real.to_f / count * 100).round : 0,
        share_percent:  total.positive?  ? (count.to_f / total * 100).round : 0,
        avg_rating:     ratings.any? ? (ratings.sum / ratings.size).round(1) : 0.0
      }
    end
  end

  def empty_category_breakdown
    %i[positive neutral negative].each_with_object({}) do |k, h|
      h[k] = { count: 0, fake: 0, real: 0, genuine_percent: 0, share_percent: 0, avg_rating: 0.0 }
    end
  end
end
