class Context < ApplicationRecord
  belongs_to :user
  has_many :lists, dependent: :nullify

  validates :name, presence: true,
                   length: { maximum: 100 },
                   uniqueness: { scope: :user_id }
  validates :user, presence: true
end
