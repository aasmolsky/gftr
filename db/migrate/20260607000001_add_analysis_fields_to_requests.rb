# frozen_string_literal: true

class AddAnalysisFieldsToRequests < ActiveRecord::Migration[8.1]
  def change
    change_table :requests, bulk: true do |t|
      t.string  :place_id
      t.string  :language, null: false, default: "en", limit: 10

      t.jsonb   :place_data_json, null: false, default: {}
      t.jsonb   :serp_reviews_json, null: false, default: []
      t.jsonb   :frai_result_json, null: false, default: {}

      t.string   :analysis_status, null: false, default: "pending"
      t.text     :analysis_error
      t.datetime :analyzed_at

      t.string   :llm_provider
      t.string   :llm_model
    end

    add_index :requests, :place_id
    add_index :requests, [:place_id, :language]
    add_index :requests, :analysis_status
    add_index :requests, :analyzed_at
  end
end
