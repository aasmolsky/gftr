# frozen_string_literal: true
# desc: Combines parsed review data with the LLM summary into the final report JSON

require_relative "services/key_conclusions_composer"

def call(input)
  data     = input[:data] || input
  llm_data = input[:llm_data]

  factual = GftReviewer::KeyConclusionsComposer.new(data).factual_paragraph

  llm_tendencies = case llm_data
                   when Array
                     llm_data.map(&:to_s).map(&:strip).reject(&:empty?)
                   when Hash
                     Array(llm_data[:key_tendencies] || llm_data["key_tendencies"]).map(&:to_s).map(&:strip).reject(&:empty?)
                   else
                     llm_data.to_s.split(/\n{2,}/).map(&:strip).reject(&:empty?)
                   end

  report = {
    place_id:                 data[:place_id],
    language:                 data[:language],
    place_data:               data[:place_data],
    declared_rating:          data[:declared_rating],
    manipulation_assessment:  data[:manipulation_assessment],
    authenticity_score:       data[:authenticity_score],
    real_only_average_rating: data[:real_only_average_rating],
    estimated_rating:         data[:estimated_rating],
    analyzed_count:           data[:analyzed_count],
    fake_count:               data[:fake_count],
    uncertain_count:          data[:uncertain_count],
    real_count:               data[:real_count],
    category_stats:           data[:category_stats],
    signal_summary:           data[:signal_summary],
    key_tendencies:           [factual, *llm_tendencies].reject(&:empty?)
  }.compact

  { report: report }
end
