# frozen_string_literal: true

#!/usr/bin/env ruby
# frozen_string_literal: true
# desc: Parses scored reviews from AnalyzeReviews::Task and returns computed review report JSON

require 'json'
require_relative 'services/runner'
payload = JSON.parse($stdin.read, symbolize_names: true)
parsed = PrepareLLMReport::Runner.call(payload)

puts JSON.generate(prepared_data: parsed)
