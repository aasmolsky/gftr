# frozen_string_literal: true

require_relative "../spec_helper"
require_relative "../../tasks/build_report/scripts/services/key_conclusions_composer"

RSpec.describe GftReviewer::KeyConclusionsComposer do
  let(:data) do
    {
      language: "en",
      place_data: {
        title: "Old school custom CLASSIC GARAGE",
        rating: 4.7,
        reviews_count: 120,
        address: "ul. Przyklad 1, Wrocław"
      },
      declared_rating: 4.7,
      analyzed_count: 12,
      estimated_rating: 3.21,
      fake_count: 5,
      uncertain_count: 1,
      real_count: 6,
      manipulation_assessment: "untrusted"
    }
  end

  it "uses Serp-sourced place metadata verbatim" do
    text = described_class.new(data).factual_paragraph

    expect(text).to include("Old school custom CLASSIC GARAGE")
    expect(text).to include("ul. Przyklad 1, Wrocław")
    expect(text).to include("4.70★")
    expect(text).to include("120")
    expect(text).to include("3.21★")
    expect(text).to include("low authenticity")
    expect(text).not_to include("123 Main St")
    expect(text).not_to include("Anytown")
  end
end
