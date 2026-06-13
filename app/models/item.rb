class Item < ApplicationRecord
  include SoftDeletable
  include Auditable

  belongs_to :list
  belongs_to :user

  enum :priority, { low: 0, medium: 1, high: 2 }, prefix: true

  validates :title, presence: true, length: { maximum: 255 }
  validates :list, presence: true
  validates :user, presence: true

  scope :overdue, -> { where("due_date < ? AND completed = false", Date.current) }

  before_save :manage_completed_at

  private

  def manage_completed_at
    if completed? && completed_at.nil?
      self.completed_at = Time.current
    elsif !completed?
      self.completed_at = nil
    end
  end
end
