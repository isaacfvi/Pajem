class ChatMessage < ApplicationRecord
  belongs_to :user

  validates :role, presence: true, inclusion: { in: %w[ user assistant ] }
  validates :content, presence: true
  validates :user, presence: true
end
