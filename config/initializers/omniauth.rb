# frozen_string_literal: true

OmniAuth.config.logger = Rails.logger
OmniAuth.config.full_host = Rails.env.production? ? ENV["HOST"] : "http://localhost:3000"

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
    ENV["GOOGLE_CLIENT_ID"],
    ENV["GOOGLE_CLIENT_SECRET"],
    scope: ["email", "profile"],
    access_type: "online",
    prompt: "consent",
    provider_ignores_state: Rails.env.development?
end
