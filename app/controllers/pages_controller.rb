# frozen_string_literal: true

class PagesController < ApplicationController
  before_action :require_login, except: [:index]

  def index
    if current_user
      @requests = current_user.requests.order(created_at: :desc).limit(10)
      if flash[:show_analysis]
        @last_request  = @requests.first
        @last_analysis = @last_request&.frai_result_json.presence || session[:last_analysis]
      end
    else
      @requests = []
    end
  end

  def query
    language = params[:hl].presence || "en"
    session[:hl] = language

    result = ReviewQueryService.call(query_text: params[:query].to_s.strip, language: language)

    session[:last_analysis] = "not_found" if result.not_found?

    current_user.requests.create(
      result.request_attrs.merge(query: params[:query].to_s.strip, response: result.response_text)
    )

    flash[:show_analysis] = true
    redirect_to root_path
  end

  private

  def require_login
    redirect_to root_path, alert: "Please log in first" unless current_user
  end

end
