# frozen_string_literal: true

module GftReviewer
  # Builds factual Key Conclusions paragraph from trusted pipeline data (SerpAPI),
  # not from LLM-generated fields.
  class KeyConclusionsComposer
    ASSESSMENT_LABELS = {
      "untrusted" => "low authenticity",
      "trusted" => "high authenticity",
      "looks_real" => "mixed authenticity",
      "mixed" => "mixed authenticity"
    }.freeze

    TEMPLATE = "%<title>s (%<address>s) shows a declared rating of %<declared>s★ based on %<total_reviews>s Google Maps reviews. " \
               "This report analyzed %<analyzed>s reviews and estimates an adjusted rating of %<estimated>s★ " \
               "(%<fake>s flagged as likely fake, %<uncertain>s uncertain, %<real>s likely genuine). " \
               "Overall assessment: %<assessment>s."

    def initialize(data)
      @data = symbolize_keys(data)
    end

    def factual_paragraph
      format(TEMPLATE, template_fields)
    end

    private

    attr_reader :data

    def place
      symbolize_keys(data[:place_data] || {})
    end

    def template_fields
      {
        title:         present(place[:title]) || "—",
        address:       present(place[:address]) || "address not provided",
        declared:      format_rating(data[:declared_rating] || place[:rating]),
        total_reviews: place[:reviews_count] || "—",
        analyzed:      data[:analyzed_count] || 0,
        estimated:     format_rating(data[:estimated_rating]),
        fake:          data[:fake_count] || 0,
        uncertain:     data[:uncertain_count] || 0,
        real:          data[:real_count] || 0,
        assessment:    assessment_label
      }
    end

    def format_rating(value)
      return "—" if value.nil?

      format("%.2f", value.to_f)
    end

    def assessment_label
      key = data[:manipulation_assessment].to_s
      ASSESSMENT_LABELS[key] || key.tr("_", " ")
    end

    def present(value)
      return nil if value.nil?

      str = value.to_s.strip
      str.empty? ? nil : str
    end

    def symbolize_keys(value)
      case value
      when Hash
        value.each_with_object({}) do |(key, nested), hash|
          hash[key.to_sym] = symbolize_keys(nested)
        end
      when Array
        value.map { |item| symbolize_keys(item) }
      else
        value
      end
    end
  end
end
