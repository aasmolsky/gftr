# frozen_string_literal: true

require "frai"

module GftReviewer
  module EnvLoader
    module_function

    def load!(path)
      return unless File.file?(path)

      File.foreach(path) do |line|
        line = line.strip
        next if line.empty? || line.start_with?("#")

        key, value = line.split("=", 2)
        next unless key

        value = value.to_s.strip
        next if value.empty? && ENV.key?(key)

        ENV[key] ||= value
      end
    end
  end
end

project_root = File.expand_path("..", __dir__)
rails_root   = File.expand_path("../..", __dir__)

GftReviewer::EnvLoader.load!(File.join(rails_root, ".env"))
GftReviewer::EnvLoader.load!(File.join(project_root, ".env"))

Frai.autoload!(project_root)

Frai.configure do |config|
  config.project_root    = project_root
  config.env             = ENV.fetch("FRAI_ENV", "production")
  config.model           = ENV["LLM_MODEL"].to_s.strip.empty? ? nil : ENV["LLM_MODEL"]
  config.api_key         = ENV["LLM_API_KEY"].to_s.strip.empty? ? nil : ENV["LLM_API_KEY"]
  config.default_retries = 0
end
