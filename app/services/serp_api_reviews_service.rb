# frozen_string_literal: true

class SerpApiReviewsService
  def initialize(api_key = ENV['SERP_API_KEY'])
    @api_key = api_key
  end

  def fetch_reviews(place_id, sort_by: "quality", max_pages: 5, hl: "en")
    stub_file = "reviews_#{place_id}.json"
    if File.exist?(stub_file)
      data = JSON.parse(File.read(stub_file), symbolize_names: true)
      if data.is_a?(Array)
        return { reviews: data, count: data.size, stubbed: true }
      else
        return data.merge(stubbed: true)
      end
    end

    return { error: "API Key is missing" } if @api_key.blank? || @api_key == 'stub'

    all_reviews = []
    next_page_token = nil

    client = SerpApi::Client.new(api_key: @api_key)

    max_pages.times do |i|
      params = {
        engine: "google_maps_reviews",
        place_id: place_id,
        sort_by: sort_by,
        hl: hl
      }
      params[:next_page_token] = next_page_token if next_page_token

      result = client.search(params)

      if result[:error]
        return { error: result[:error], reviews: all_reviews }
      end

      reviews = result[:reviews] || []
      all_reviews.concat(reviews)

      place_info = result[:place_info] || {}
      
      metadata ||= {
        title: place_info[:title],
        rating: place_info[:rating],
        reviews_count: place_info[:reviews],
        address: place_info[:address]
      }

      next_page_token = result.dig(:serpapi_pagination, :next_page_token)
      break unless next_page_token
    end

    { 
      reviews: all_reviews, 
      count: all_reviews.size,
      title: metadata&.dig(:title),
      rating: metadata&.dig(:rating),
      reviews_count: metadata&.dig(:reviews_count),
      address: metadata&.dig(:address)
    }
  rescue StandardError => e
    { error: e.message }
  end

  def find_place_id(query)
    return nil if @api_key.blank? || @api_key == 'stub'

    client = SerpApi::Client.new(api_key: @api_key)
    result = client.search({
      engine: "google_maps",
      q: query,
      type: "search"
    })

    if result[:place_results] && result[:place_results][:place_id]
      return result[:place_results][:place_id]
    end

    if result[:local_results] && result[:local_results].is_a?(Array)
      return result[:local_results].first[:place_id]
    end

    nil
  rescue StandardError
    nil
  end
end
