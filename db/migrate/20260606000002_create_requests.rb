# frozen_string_literal: true

class CreateRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :requests do |t|
      t.references :user, null: false, foreign_key: true
      t.text :query, null: false
      t.text :response, null: false

      t.timestamps
    end

    add_index :requests, :created_at
  end
end
