# frozen_string_literal: true

require_relative 'category_stats_builder'
require_relative 'signal_summary_builder'

module PrepareLLMReport
  class ReportBuilder
    def initialize(input, labeled_reviews)
      @input = input
      @labeled_reviews = labeled_reviews
    end

    def call
      total = labeled_reviews.size
      fake  = count_by_label('fake')
      real  = count_by_label('real')

      {
        place_id:                input[:place_id],
        language:                input[:language],
        place_data:              input[:place_data],
        declared_rating:         input[:place_data][:rating],
        manipulation_assessment: derive_assessment(fake, real, total),
        authenticity_score:      total.positive? ? (fake.to_f / total * 100).round : 0,
        real_only_average_rating: real_only_average_rating,
        estimated_rating:        estimated_rating,
        analyzed_count:          total,
        fake_count:              fake,
        uncertain_count:         count_by_label('uncertain'),
        real_count:              real,
        category_stats:          CategoryStatsBuilder.new(labeled_reviews, language: input[:language]).call,
        signal_summary:          SignalSummaryBuilder.new(labeled_reviews).call
      }
    end

    private

    attr_reader :input, :labeled_reviews

    def derive_assessment(fake_count, real_count, total)
      return 'looks_real' unless total.positive?

      if fake_count.to_f / total >= 0.25
        'untrusted'
      elsif real_count.to_f / total > 0.8
        'trusted'
      else
        'looks_real'
      end
    end

    def count_by_label(label)
      labeled_reviews.count { |review| review[:label] == label }
    end

    def real_reviews
      labeled_reviews.select { |review| review[:label] == 'real' }
    end

    def real_only_average_rating
      ratings = real_reviews.map { |review| review[:rating].to_f }.reject(&:zero?)
      return 0.0 unless ratings.any?

      (ratings.sum / ratings.size).round(2)
    end

    def estimated_rating
      total_count = labeled_reviews.size
      real_avg = real_only_average_rating
      return 0.0 unless total_count.positive? && real_avg.positive?

      real_count = count_by_label('real')
      fake_count = count_by_label('fake')

      ((real_avg * real_count + 2.5 * fake_count) / total_count).round(2)
    end
  end
end
