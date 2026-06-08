# frozen_string_literal: true

# == Schema Information
#
# Table name: requests
#
#  id                :integer          not null, primary key
#  user_id           :integer          not null
#  query             :text             not null
#  response          :text             not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  place_id          :string
#  language          :string(10)       default("en"), not null
#  place_data_json   :jsonb            default("{}"), not null
#  serp_reviews_json :jsonb            default("[]"), not null
#  frai_result_json  :jsonb            default("{}"), not null
#  analysis_status   :string           default("pending"), not null
#  analysis_error    :text
#  analyzed_at       :datetime
#  llm_provider      :string
#  llm_model         :string
#
# Indexes
#
#  index_requests_on_analysis_status        (analysis_status)
#  index_requests_on_analyzed_at            (analyzed_at)
#  index_requests_on_created_at             (created_at)
#  index_requests_on_place_id               (place_id)
#  index_requests_on_place_id_and_language  (place_id,language)
#  index_requests_on_user_id                (user_id)
#

class Request < ApplicationRecord
  belongs_to :user

  validates :user_id, :query, :response, presence: true
end
