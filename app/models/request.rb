class Request < ApplicationRecord
  belongs_to :user

  validates :user_id, :query, :response, presence: true
end