class PagesController < ApplicationController
  before_action :require_login, except: [:index]

  def index
    if current_user
      @requests = current_user.requests.order(created_at: :desc).limit(10)
      @last_request = @requests.first
      @last_analysis = @last_request&.frai_result_json.presence || session[:last_analysis]
    else
      @requests = []
    end
  end

  def query
    query_text = params[:query]
    language = params[:hl] || "en"
    session[:hl] = language
    request_attrs = { query: query_text }

    if query_text.downcase.match?(/reviews for|отзывы для/) || (query_text.start_with?('ChI') && query_text.length > 20)
      search_term = query_text.gsub(/reviews for|отзывы для/i, '').strip

      service = SerpApiReviewsService.new

      place_id = if search_term.start_with?('ChI') && search_term.length > 20
        search_term
      else
        service.find_place_id(search_term)
      end

      if place_id
        result = service.fetch_reviews(place_id, hl: language)
        if result[:error]
          response_text = "Error fetching reviews: #{result[:error]}"
          session[:last_analysis] = "not_found"
        else
          analysis = FraiReviewsAnalysisService.new.call(
            place_id: place_id,
            language: language,
            serp_result: result
          )

          reviews_count = result[:count]
          first_review = result[:reviews].first&.dig(:snippet) || "No review text"
          stub_msg = result[:stubbed] ? "[STUB DATA] " : ""

          details = []
          details << "Title: #{result[:title]}" if result[:title]
          details << "Rating: #{result[:rating]}" if result[:rating]
          details << "Total Reviews: #{result[:reviews_count]}" if result[:reviews_count]
          details << "Address: #{result[:address]}" if result[:address]

          details_str = details.any? ? " (#{details.join(', ')})" : ""
          calculated_rating = analysis.dig(:frai_result_json, :calculated_rating) || result[:rating]
          analyzed_count = analysis.dig(:frai_result_json, :analyzed_ratings_count) || reviews_count
          response_text = "#{stub_msg}Place found (ID: #{place_id})#{details_str}. Reviews found in request: #{reviews_count}. First review: #{first_review}. Analysis rating: #{calculated_rating}"

          session[:last_analysis] = {
            title: result[:title],
            rating: calculated_rating,
            reviews_count: result[:reviews_count],
            address: result[:address],
            analyzed_count: analyzed_count
          }

          request_attrs.merge!(
            place_id: place_id,
            language: language,
            place_data_json: analysis[:place_data_json],
            serp_reviews_json: analysis[:serp_reviews_json],
            frai_result_json: analysis[:frai_result_json],
            analysis_status: analysis[:analysis_status],
            analysis_error: analysis[:analysis_error],
            analyzed_at: analysis[:analyzed_at],
            llm_provider: analysis[:llm_provider],
            llm_model: analysis[:llm_model]
          )
        end
      else
        response_text = "Could not find place for: '#{search_term}'"
        session[:last_analysis] = "not_found"
      end
    else
      response_text = "You asked: '#{query_text}'. To get reviews, write 'reviews for [PLACE_ID or NAME]'"
      session[:last_analysis] = "not_found"
    end

    current_user.requests.create(request_attrs.merge(response: response_text))
    redirect_to root_path
  end

  private


  def require_login
    redirect_to root_path, alert: "Please log in first" unless current_user
  end

end