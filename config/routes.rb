# frozen_string_literal: true

Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "pages#index"

  post "query", to: "pages#query"

  # OmniAuth callback routes
  match "/auth/:provider/callback", to: "sessions#google_callback", via: [:get, :post]
  get "/auth/failure", to: "sessions#failure"
  delete "/logout", to: "sessions#destroy"
end
