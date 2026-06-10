# frozen_string_literal: true

require_relative '../../spec_helper'

RSpec.describe BuildReport::Task do
  describe '.call' do
    subject(:report) do
      described_class.call(data: data, llm_data: llm_data)
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
        manipulation_assessment: 'untrusted',
        authenticity_score: 40,
        real_only_average_rating: 4.8,
        estimated_rating: 3.7,
        analyzed_count: 10,
        fake_count: 2,
        uncertain_count: 1,
        real_count: 7,
        category_stats: {
          positive: {
            total: 4, real: 2, uncertain: 1, fake: 1,
            genuine_percent: 50, share_percent: 80, avg_rating: 4.8,
            manipulation_signals: 5, authenticity_signals: 5, suspicious_reviews: []
          },
          neutral: {
            total: 0, real: 0, uncertain: 0, fake: 0,
            genuine_percent: 0, share_percent: 0, avg_rating: 0.0,
            manipulation_signals: 0, authenticity_signals: 0, suspicious_reviews: []
          },
          negative: {
            total: 1, real: 0, uncertain: 0, fake: 1,
            genuine_percent: 0, share_percent: 20, avg_rating: 1.0,
            manipulation_signals: 1, authenticity_signals: 0, suspicious_reviews: []
          }
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
      expect(report[:key_tendencies].first).to include('Test Garage')
      expect(report[:key_tendencies].first).to include('Test St 1')
      expect(report[:key_tendencies].drop(1)).to eq([
        'Many reviews use generic praise without concrete details.',
        'Unusually fast owner replies to negative reviews stand out.'
      ])
    end
  end
end
