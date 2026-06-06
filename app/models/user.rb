class User < ApplicationRecord
  has_many :requests, dependent: :destroy

  validates :google_id, :email, presence: true
  validates :google_id, uniqueness: true

  def self.find_or_create_from_google(auth)
    where(google_id: auth['uid']).first_or_create do |user|
      user.email = auth['info']['email']
      user.name = auth['info']['name']
    end
  end
end