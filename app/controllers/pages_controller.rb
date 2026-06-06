class PagesController < ApplicationController
  before_action :require_login, except: [:index]

  def index
    if current_user
      @requests = current_user.requests.order(created_at: :desc).limit(10)
      @last_analysis = session[:last_analysis]
    else
      @requests = []
    end
  end

  def query
    query_text = params[:query]
    language = params[:hl] || "en"
    session[:hl] = language

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
          reviews_count = result[:count]
          first_review = result[:reviews].first&.dig(:snippet) || "No review text"
          stub_msg = result[:stubbed] ? "[STUB DATA] " : ""
          
          details = []
          details << "Title: #{result[:title]}" if result[:title]
          details << "Rating: #{result[:rating]}" if result[:rating]
          details << "Total Reviews: #{result[:reviews_count]}" if result[:reviews_count]
          details << "Address: #{result[:address]}" if result[:address]
          
          details_str = details.any? ? " (#{details.join(', ')})" : ""
          response_text = "#{stub_msg}Place found (ID: #{place_id})#{details_str}. Reviews found in request: #{reviews_count}. First review: #{first_review}"

          session[:last_analysis] = {
            title: result[:title],
            rating: result[:rating],
            reviews_count: result[:reviews_count],
            address: result[:address],
            analyzed_count: reviews_count
          }
        end
      else
        response_text = "Could not find place for: '#{search_term}'"
        session[:last_analysis] = "not_found"
      end
    else
      response_text = "You asked: '#{query_text}'. To get reviews, write 'reviews for [PLACE_ID or NAME]'"
      session[:last_analysis] = "not_found"
    end

    current_user.requests.create(
      query: query_text,
      response: response_text
    )

    redirect_to root_path, notice: "Request processed successfully"
  end

  private


  def require_login
    redirect_to root_path, alert: "Please log in first" unless current_user
  end

end