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
  #     reviews:    [...],
  #     max_groups: 5
  #   )
  class Application < Frai::Application
    def call(place_id:, language:, place_data:, reviews:)
      ReviewAnalysisPipeline.call({
        place_id:   place_id,
        language:   language,
        place_data: place_data,
        reviews:    reviews
      })
    end
  end
end

