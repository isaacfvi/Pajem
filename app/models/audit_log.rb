class AuditLog < ApplicationRecord
  VALID_ACTIONS = %w[ created updated deleted restored completed uncompleted shared unshared ].freeze
  VALID_ORIGINS = %w[ manual assistant ].freeze

  belongs_to :user, optional: true
  belongs_to :auditable, polymorphic: true

  validates :action, presence: true, inclusion: { in: VALID_ACTIONS }
  validates :origin, presence: true, inclusion: { in: VALID_ORIGINS }
  validates :auditable, presence: true

  def self.record(user:, action:, auditable:, origin: "manual", changes: nil)
    create(user: user, action: action, auditable: auditable, origin: origin, changeset: changes)
  end
end
