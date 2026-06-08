# frozen_string_literal: true

# == Schema Information
#
# Table name: users
#
#  id         :integer          not null, primary key
#  google_id  :string           not null
#  email      :string           not null
#  name       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_users_on_google_id  (google_id) UNIQUE
#

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
