# frozen_string_literal: true

require_relative '../../spec_helper'

RSpec.describe SummarizeReviews::Task do
  describe '.call' do
    subject(:prompt) do
      described_class.call(
        data: data,
        language: 'en'
      )
    end

    let(:data) do
      {
        place_id: 'ChIJtest123',
        language: 'en',
        place_data: {
          title: 'Test Garage',
          rating: 4.5,
          reviews_count: 78,
          address: 'Test St 1'
        },
        declared_rating: 4.5,
        real_only_average_rating: 4.8,
        estimated_rating: 3.7,
        analyzed_count: 10,
        fake_count: 2,
        uncertain_count: 1,
        real_count: 7,
        category_stats: {
          positive: { count: 6, real: 4, fake: 1, uncertain: 1, avg_rating: 4.8 },
          neutral:  { count: 2, real: 2, fake: 0, uncertain: 0, avg_rating: 3.0 },
          negative: { count: 2, real: 1, fake: 1, uncertain: 0, avg_rating: 1.5 }
        },
        signal_summary: {
          GENERIC_TEXT: 4,
          SHORT_TEXT: 3,
          LOCAL_GUIDE: 5
        }
      }
    end

    it 'renders the expected summary prompt', :aggregate_failures do
      expect(prompt).to include('You are a review analysis assistant. Use the structured review data below to write a concise, human-readable summary in en.')
      expect(prompt).to include('Write 2–4 short paragraphs.')
      expect(prompt).to include('Focus on the strongest numerical trends, suspicious patterns, and clear case statements supported by the data.')
      expect(prompt).to include(data.to_json)
      expect(prompt).to include('"language":"en"')
      expect(prompt).to include('Do not return JSON, bullets, markdown headings, or tables.')
    end
  end
end
