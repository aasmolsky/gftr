# frozen_string_literal: true

module CategoryStatsFixture
  EMPTY_BUCKET = {
    total: 0, real: 0, uncertain: 0, fake: 0,
    genuine_percent: 0, share_percent: 0, avg_rating: 0.0,
    manipulation_signals: 0, authenticity_signals: 0, suspicious_reviews: []
  }.freeze

  def self.build(positive: {}, neutral: {}, negative: {})
    {
      positive: EMPTY_BUCKET.merge(positive),
      neutral: EMPTY_BUCKET.merge(neutral),
      negative: EMPTY_BUCKET.merge(negative)
    }
  end
end
