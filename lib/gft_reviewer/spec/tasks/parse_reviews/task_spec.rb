# frozen_string_literal: true

require_relative '../../spec_helper'

# ---------------------------------------------------------------------------
# Fixture
#
# Score math (FAKE_THRESHOLD=40, UNCERTAIN_THRESHOLD=20,
#             coeff: n>=3→2.0, n==2→1.5, n==1→1.0):
#   r1  THIN_ACCOUNT_0(15) + SHORT_TEXT(10)                           → 25*1.5 = 38  → uncertain
#   r2  GENERIC_TEXT(20) + FIVE_STAR_EMPTY(15) + ALL_POSITIVE(10)    → 45*2.0 = 90  → fake
#   r3  LOCAL_GUIDE(-10) + EXPERIENCED_AUTHOR_5(-5) + SPECIFIC(-15)  → -30*2.0 = -60 → real
#   r4  SHORT_TEXT(10) + SUSPICIOUS_NEGATIVE(20)                      → 30*1.5 = 45  → fake
#   r5  OWNER_RESPONDED(-5) + SPECIFIC_DETAILS(-15)                   → -20*1.5 = -30 → real
# ---------------------------------------------------------------------------
RSpec.describe ParseReviews::Task do
  describe '.call' do
    subject(:result) do
      described_class.call(
        llm_response: JSON.generate(
          place_id:          'ChIJtest123',
          language:          'en',
          place_data:        { title: 'Wrong Title', rating: 1.0, reviews_count: 1, address: 'Fake St' },
          processed_reviews: reviews
        ),
        place_data: place_data
      )
    end

    let(:place_data) { { title: 'Test Garage', rating: 4.5, reviews_count: 5, address: 'Test St 1' } }
    let(:reviews) do
      [
        {
          review_id: 'r1', rating: 5, author_name: 'Alice', snippet: 'Great!',
          score_breakdown: { 'THIN_ACCOUNT_0' => 15, 'SHORT_TEXT' => 10 }
        },
        {
          review_id: 'r2', rating: 5, author_name: 'Bob',
          snippet: 'Excellent service, highly recommend!',
          score_breakdown: { 'GENERIC_TEXT' => 20, 'FIVE_STAR_EMPTY' => 15, 'ALL_POSITIVE' => 10 }
        },
        {
          review_id: 'r3', rating: 5, author_name: 'Carol',
          snippet: 'Replaced timing belt, quick and fair price',
          score_breakdown: { 'LOCAL_GUIDE' => -10, 'EXPERIENCED_AUTHOR_5' => -5, 'SPECIFIC_DETAILS' => -15 }
        },
        {
          review_id: 'r4', rating: 1, author_name: 'Dave', snippet: 'Bad',
          score_breakdown: { 'SHORT_TEXT' => 10, 'SUSPICIOUS_NEGATIVE' => 20 }
        },
        {
          review_id: 'r5', rating: 4, author_name: 'Eve',
          snippet: 'Good workshop, fixed my brakes',
          score_breakdown: { 'OWNER_RESPONDED' => -5, 'SPECIFIC_DETAILS' => -15 }
        }
      ]
    end

    # r2(fake), r4(fake) → 2; r1(uncertain) → 1; r3(real), r5(real) → 2
    # real: r3(5★) + r5(4★) → avg = 4.5
    # estimated: (4.5*2 + 2.5*2) / 5 = 2.8
    context 'when a successful result is returned' do
      subject(:report) { result }

      it 'returns top-level metadata', :aggregate_failures do
        expect(report[:place_id]).to eq('ChIJtest123')
        expect(report[:language]).to eq('en')
        expect(report[:place_data][:title]).to eq('Test Garage')
        expect(report[:declared_rating]).to eq(4.5)
        expect(report[:analyzed_count]).to eq(5)
      end

      it 'assigns labels and counts them', :aggregate_failures do
        expect(report[:fake_count]).to eq(2)
        expect(report[:uncertain_count]).to eq(1)
        expect(report[:real_count]).to eq(2)
      end

      it 'computes ratings from real reviews only', :aggregate_failures do
        expect(report[:real_only_average_rating]).to eq(4.5)
        expect(report[:estimated_rating]).to eq(2.8)
      end

      describe 'category_stats' do
        describe 'positive (4–5★)' do
          it 'aggregates totals and label counts', :aggregate_failures do
            pos = report[:category_stats][:positive]
            expect(pos[:total]).to eq(4)
            expect(pos[:real]).to eq(2)
            expect(pos[:uncertain]).to eq(1)
            expect(pos[:fake]).to eq(1)
            expect(pos[:avg_rating]).to be_within(0.05).of(4.75)
          end

          it 'counts manipulation and authenticity signals', :aggregate_failures do
            pos = report[:category_stats][:positive]
            expect(pos[:manipulation_signals]).to eq(5)
            expect(pos[:authenticity_signals]).to eq(5)
          end

          it 'lists suspicious reviews ordered by severity', :aggregate_failures do
            pos = report[:category_stats][:positive]
            ids = pos[:suspicious_reviews].map { |r| r[:review_id] }
            expect(ids.first).to eq('r2')
            expect(ids).to include('r1')
            expect(pos[:suspicious_reviews].size).to be <= 3
          end

          it 'includes required fields in each suspicious entry' do
            pos = report[:category_stats][:positive]
            entry = pos[:suspicious_reviews].first
            expect(entry.keys).to include(:review_id, :author_name, :rating,
                                          :snippet, :label, :computed_score, :score_breakdown, :display_signals)
          end

          it 'adds human-readable display_signals for UI' do
            pos = report[:category_stats][:positive]
            entry = pos[:suspicious_reviews].find { |review| review[:review_id] == 'r2' }
            texts = Array(entry[:display_signals]).map { |signal| signal[:text] }

            expect(texts).to include('Few concrete details')
            expect(texts).to include('Uniformly positive tone')
            kinds = Array(entry[:display_signals]).map { |signal| signal[:kind] }
            expect(kinds).to all(eq('negative'))
          end
        end

        describe 'neutral (3★)' do
          it 'is empty' do
            neu = report[:category_stats][:neutral]
            expect(neu[:total]).to eq(0)
          end
        end

        describe 'negative (1–2★)' do
          it 'contains r4 as the sole fake review', :aggregate_failures do
            neg = report[:category_stats][:negative]
            expect(neg[:total]).to eq(1)
            expect(neg[:fake]).to eq(1)
            expect(neg[:suspicious_reviews].map { |r| r[:review_id] }).to include('r4')
          end
        end
      end

      describe 'signal_summary' do
        it 'is a non-empty hash sorted by count descending', :aggregate_failures do
          summary = report[:signal_summary]
          expect(summary).to be_a(Hash)
          expect(summary).not_to be_empty
          counts = summary.values
          expect(counts).to eq(counts.sort.reverse)
        end

        it 'counts occurrences across all reviews', :aggregate_failures do
          summary = report[:signal_summary]
          expect(summary[:SHORT_TEXT]).to eq(2)
          expect(summary[:SPECIFIC_DETAILS]).to eq(2)
        end

        it 'includes all criterion keys from the fixture' do
          summary = report[:signal_summary]
          expect(summary.keys).to include(
            :THIN_ACCOUNT_0, :SHORT_TEXT, :GENERIC_TEXT, :FIVE_STAR_EMPTY,
            :ALL_POSITIVE, :LOCAL_GUIDE, :EXPERIENCED_AUTHOR_5,
            :SPECIFIC_DETAILS, :SUSPICIOUS_NEGATIVE, :OWNER_RESPONDED
          )
        end
      end
    end

    context 'when LLM output lacks snippets' do
      subject(:report) do
        described_class.call(
          llm_response: {
            place_id:          'ChIJtest123',
            language:          'en',
            place_data:        { title: 'Wrong', rating: 0, reviews_count: 0, address: 'Wrong' },
            processed_reviews: [
              {
                review_id: 'r1', rating: 5, author_name: 'Alice',
                score_breakdown: { 'THIN_ACCOUNT_0' => 15, 'SHORT_TEXT' => 10 }
              }
            ]
          },
          source_reviews: [
            { review_id: 'r1', snippet: 'Very detailed review text from SerpAPI' }
          ],
          place_data: place_data
        )
      end

      it 'restores snippets from source_reviews into suspicious_reviews' do
        pos = report[:category_stats][:positive]
        snippet = pos[:suspicious_reviews].find { |r| r[:review_id] == 'r1' }&.dig(:snippet)
        expect(snippet).to eq('Very detailed review text from SerpAPI')
      end
    end

    context 'when input is a structured Hash from AnalyzeReviews' do
      subject(:report) do
        described_class.call(
          llm_response: {
            place_id:          'ChIJtest123',
            language:          'en',
            place_data:        { title: 'Wrong', rating: 0 },
            processed_reviews: reviews
          },
          place_data: place_data
        )
      end

      it 'parses without string coercion' do
        expect(report[:analyzed_count]).to eq(5)
      end
    end

    context 'when analysis language is russian' do
      it 'localizes display signals to russian' do
        report = described_class.call(
          llm_response: {
            place_id: 'ChIJtest123',
            language: 'ru',
            place_data: { title: 'Wrong', rating: 0 },
            processed_reviews: [
              {
                review_id: 'r1',
                rating: 5,
                author_name: 'Alice',
                score_breakdown: { 'THIN_ACCOUNT_0' => 15, 'SHORT_TEXT' => 10 }
              }
            ]
          },
          place_data: place_data
        )

        signals = Array(report.dig(:category_stats, :positive, :suspicious_reviews, 0, :display_signals))
        texts = signals.map { |signal| signal[:text] }
        expect(texts).to include('Небольшая история отзывов')
        expect(signals).to all(include(kind: 'negative'))
      end
    end

    context 'when input is a legacy JSON string' do
      subject(:report) do
        json = JSON.generate(
          place_id: 'ChIJtest123', language: 'en',
          place_data: place_data, processed_reviews: []
        )
        described_class.call(llm_response: json, place_data: place_data)
      end

      it 'coerces string params to Hash and parses successfully' do
        expect(report[:place_id]).to eq('ChIJtest123')
        expect(report[:analyzed_count]).to eq(0)
      end
    end

    context 'when input has trailing-comma malformed JSON' do
      it 'repairs and parses successfully' do
        json = "{\"place_id\":\"x\",\"language\":\"en\",\"place_data\":{},\"processed_reviews\":[]}"
        expect { described_class.call(llm_response: json, place_data: place_data) }.not_to raise_error
      end
    end
  end
end
