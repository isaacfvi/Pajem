class Context < ApplicationRecord
  belongs_to :user
  has_many :lists, dependent: :nullify

  validates :name, presence: true,
                   length: { maximum: 100 },
                   uniqueness: { scope: :user_id }
  validates :user, presence: true

  after_create_commit  :broadcast_context_created
  after_update_commit  :broadcast_context_updated
  after_destroy_commit :broadcast_context_destroyed

  private

  def broadcast_context_created
    broadcast_append_to [ user, :contexts ],
      target:  "sidebar_contexts",
      partial: "contexts/context_item",
      locals:  { context: self }
  end

  def broadcast_context_updated
    broadcast_replace_to [ user, :contexts ],
      target:  dom_id(self),
      partial: "contexts/context_item",
      locals:  { context: self }
  end

  def broadcast_context_destroyed
    broadcast_remove_to [ user, :contexts ], target: dom_id(self)
  end
end
