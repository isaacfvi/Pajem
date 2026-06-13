module SoftDeletable
  extend ActiveSupport::Concern

  included do
    include Discard::Model
    self.discard_column = :deleted_at
    default_scope { kept }
    scope :discarded, -> { unscope(where: :deleted_at).where.not(deleted_at: nil) }
  end
end
