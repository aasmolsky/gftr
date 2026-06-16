# frozen_string_literal: true
# desc: Parses scored reviews from AnalyzeReviews::Task and returns computed review report JSON

require_relative "services/runner"

def call(input)
  { prepared_data: PrepareLLMReport::Runner.call(input) }
end
