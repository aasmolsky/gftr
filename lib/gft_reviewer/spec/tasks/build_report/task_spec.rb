# frozen_string_literal: true

require_relative '../../spec_helper'

RSpec.describe BuildReport::Task do
  describe '.call' do
    subject(:report) do
      JSON.parse(
        described_class.call(
          data: data,
          llm_data: llm_data
        ),
        symbolize_names: true
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
          neutral: { count: 2, real: 2, fake: 0, uncertain: 0, avg_rating: 3.0 },
          negative: { count: 2, real: 1, fake: 1, uncertain: 0, avg_rating: 1.5 }
        },
        signal_summary: {
          GENERIC_TEXT: 4,
          SHORT_TEXT: 3,
          LOCAL_GUIDE: 5
        }
      }
    end

    let(:llm_data) do
      <<~TEXT
        Many reviews use generic praise without concrete details.

        Unusually fast owner replies to negative reviews stand out.
      TEXT
    end

    it 'builds the final report JSON from parsed data and LLM text', :aggregate_failures do
      expect(report[:place_id]).to eq('ChIJtest123')
      expect(report[:language]).to eq('en')
      expect(report[:fake_count]).to eq(2)
      expect(report[:real_count]).to eq(7)
      expect(report[:analyzed_count]).to eq(10)
      expect(report[:category_stats]).to eq(data[:category_stats])
      expect(report[:signal_summary]).to eq(data[:signal_summary])
      expect(report[:key_tendencies]).to eq([
        'Many reviews use generic praise without concrete details.',
        'Unusually fast owner replies to negative reviews stand out.'
      ])
    end
  end
end
