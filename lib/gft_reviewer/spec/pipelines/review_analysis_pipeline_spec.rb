# frozen_string_literal: true

require_relative "../spec_helper"

RSpec.describe GftReviewer::ReviewAnalysisPipeline do
  describe "#call" do
    let(:input) do
      {
        place_id:   "ChIJtest123",
        language:   "en",
        place_data: { title: "Test Garage", rating: 4.5, reviews_count: 5, address: "Test St 1" },
        reviews:    [
          {
            review_id: "r1", rating: 5, author_name: "Alice", snippet: "Great!",
            score_breakdown: { "THIN_ACCOUNT_0" => 15, "SHORT_TEXT" => 10 }
          },
          {
            review_id: "r2", rating: 5, author_name: "Bob",
            snippet: "Excellent service, highly recommend!",
            score_breakdown: { "GENERIC_TEXT" => 20, "FIVE_STAR_EMPTY" => 15, "ALL_POSITIVE" => 10 }
          }
        ]
      }
    end

    let(:analyzed_data) do
      {
        place_id:          input[:place_id],
        language:          input[:language],
        place_data:        input[:place_data],
        processed_reviews: input[:reviews]
      }
    end

    let(:summary_text) do
      <<~TEXT.strip
        Generic praise appears in several five-star reviews.

        Negative feedback looks more specific than positive clusters.
      TEXT
    end

    before do
      allow(AnalyzeReviews::Task).to receive(:call).and_return(analyzed_data)
      allow(SummarizeReviews::Task).to receive(:call).and_return(summary_text)
    end

    it "chains tasks and returns final report JSON", :aggregate_failures do
      report = described_class.call(input)

      expect(AnalyzeReviews::Task).to have_received(:call).with(
        place_id:   input[:place_id],
        language:   input[:language],
        place_data: input[:place_data],
        reviews:    input[:reviews]
      )

      expect(SummarizeReviews::Task).to have_received(:call).with(
        data:     hash_including(place_id: input[:place_id], analyzed_count: 2),
        language: input[:language]
      )

      expect(report[:place_id]).to eq("ChIJtest123")
      expect(report[:place_data][:title]).to eq("Test Garage")
      expect(report[:analyzed_count]).to eq(2)
      expect(report[:fake_count]).to eq(1)
      expect(report[:key_tendencies].first).to include("Test Garage")
      expect(report[:key_tendencies].first).to include("Test St 1")
      expect(report[:key_tendencies].last).to eq("Negative feedback looks more specific than positive clusters.")
    end
  end
end
