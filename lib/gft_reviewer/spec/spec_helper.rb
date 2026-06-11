# frozen_string_literal: true

ENV["FRAI_ENV"] = "test"

require "json"
require_relative "../config/frai"
require_relative "support/category_stats_fixture"

RSpec.configure do |config|
  config.around do |example|
    original_stderr = $stderr
    $stderr = File.open(File::NULL, "w")
    example.run
  ensure
    $stderr = original_stderr
  end
end
