# frozen_string_literal: true

require_relative '../../spec_helper'

RSpec.describe AnalyzeReviews::Task do
  describe '.call' do
    subject(:prompt) do
      described_class.call(
        place_id: 'ChIJtest123',
        language: 'ru',
        place_data: place_data,
        reviews: reviews
      )
    end

    let(:place_data) do
      {
        title: 'Test Garage',
        rating: 4.5,
        reviews_count: 78,
        address: 'Test St 1'
      }
    end

    let(:reviews) do
      [
        {
          review_id: 'r1',
          position: 1,
          rating: 5,
          snippet: 'Very nice guys, fixed my car in the spot, recommend this place',
          snippet_length: 64,
          author_name: 'Alice',
          author_reviews_count: 14,
          author_photos_count: 0,
          images_count: 0,
          is_local_guide: true,
          response_present: false,
          was_edited: false,
          likes: 0
        }
      ]
    end

    it 'renders the expected prompt', :aggregate_failures do
      expect(prompt).to include('You are a review fraud scorer. Score and label every review in the input.')
      expect(prompt).to include('All text fields in your response must be written in ru.')
      expect(prompt).to include('## Review scoring rules')
      expect(prompt).to include('## Pattern examples')
      expect(prompt).to include(place_data.to_json)
      expect(prompt).to include(reviews.to_json)
      expect(prompt).to include('"place_id": "ChIJtest123"')
      expect(prompt).to include('"language": "ru"')
      expect(prompt).to include('Reviews to score:')
      expect(prompt).to include('THIN_ACCOUNT_0')
      expect(prompt).to include('GENERIC_TEXT')
    end
  end
end
