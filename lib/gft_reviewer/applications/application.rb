# frozen_string_literal: true

module GftReviewer
  # Application is the public entrypoint for the GftReviewer frai project.
  #
  # Rails calls this class directly — the internal implementation can change
  # (tasks, pipelines, agents) without affecting the external call site.
  #
  # Usage from Rails:
  #   GftReviewer::Application.call(
  #     place_id:   "ChIJ...",
  #     language:   "english",
  #     place_data: { title: "...", rating: 4.5, ... },
  #     reviews:    [...]
  #   )
  class Application < Frai::Application
    def call(place_id:, language:, place_data:, reviews:)
      ensure_api_mode!

      ReviewAnalysisPipeline.call({
        place_id:   place_id,
        language:   language,
        place_data: place_data,
        reviews:    reviews
      })
    end

    private

    def ensure_api_mode!
      return if Frai.configuration.api_mode?

      env   = Frai.configuration.env
      model = Frai.configuration.model

      if Frai.configuration.dry_run?
        raise Frai::Error, <<~MSG.squish
          GftReviewer requires API mode (FRAI_ENV=production, LLM_MODEL and LLM_API_KEY set).
          Current FRAI_ENV=#{env} runs tasks in dry run and returns prompts instead of structured data.
          Pipelines cannot chain LLM steps in development/test.
        MSG
      end

      raise Frai::Error, <<~MSG.squish
        GftReviewer requires API mode: set LLM_MODEL and LLM_API_KEY in .env
        (FRAI_ENV=production). Current FRAI_ENV=#{env}, LLM_MODEL=#{model.inspect}.
      MSG
    end
  end
end
