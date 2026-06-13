class List < ApplicationRecord
  include SoftDeletable
  include Auditable

  belongs_to :user
  belongs_to :context, optional: true
  has_many :items, dependent: :destroy

  validates :title, presence: true, length: { maximum: 255 }
  validates :color, format: { with: /\A#[0-9A-Fa-f]{6}\z/ }, allow_nil: true
  validates :user, presence: true

  def progress
    total = items.kept.count
    return 0 if total.zero?
    (items.kept.where(completed: true).count.to_f / total * 100).round
  end

  def active_items
    items.kept
  end
end
