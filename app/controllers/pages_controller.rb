class PagesController < ApplicationController
  before_action :require_login, except: [:index]

  def index
    if current_user
      @requests = current_user.requests.order(created_at: :desc).limit(10)
    else
      @requests = []
    end
  end

  def query
    query_text = params[:query]

    # TODO: Integrate AI agent here
    response_text = "AI agent response will be here"

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