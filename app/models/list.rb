class List < ApplicationRecord
  include SoftDeletable
  include Auditable

  PALETTE = [
    { name: "Amarelo",  bg: "#FFF9C4", css: "color--amarelo"  },
    { name: "Verde",    bg: "#DCEDC8", css: "color--verde"    },
    { name: "Azul",     bg: "#BBDEFB", css: "color--azul"     },
    { name: "Rosa",     bg: "#FCE4EC", css: "color--rosa"     },
    { name: "Laranja",  bg: "#FFE0B2", css: "color--laranja"  },
    { name: "Lilás",    bg: "#E1BEE7", css: "color--lilas"    },
    { name: "Vermelho", bg: "#FFCDD2", css: "color--vermelho" },
    { name: "Menta",    bg: "#B2DFDB", css: "color--menta"    }
  ].freeze

  PALETTE_COLORS = PALETTE.map { |p| p[:bg] }.freeze

  belongs_to :user
  belongs_to :context, optional: true
  has_many :items, dependent: :destroy

  validates :title, presence: true, length: { maximum: 255 }
  validates :color, inclusion: { in: PALETTE_COLORS }, allow_nil: true
  validates :user, presence: true

  after_create_commit  :broadcast_list_created
  after_update_commit  :broadcast_list_updated
  after_destroy_commit :broadcast_list_destroyed
  after_commit         :bust_dashboard_cache

  def progress
    total = items.kept.count
    return 0 if total.zero?
    (items.kept.where(completed: true).count.to_f / total * 100).round
  end

  def active_items
    items.kept
  end

  private

  def broadcast_list_created
    broadcast_append_to [ user, :lists ],
      target:  "postit_grid",
      partial: "lists/postit_card",
      locals:  { list: self }
    broadcast_append_to [ user, :lists ],
      target:  "lists-page",
      partial: "lists/expanded_panel",
      locals:  { list: self }
  end

  def broadcast_list_updated
    return if share_only_update?

    if saved_change_to_deleted_at? && discarded?
      broadcast_remove_to [ user, :lists ], target: dom_id(self)
      broadcast_remove_to [ user, :lists ], target: dom_id(self, :panel)
    else
      broadcast_replace_to [ user, :lists ],
        target:  dom_id(self),
        partial: "lists/postit_card",
        locals:  { list: self }
      broadcast_replace_to [ user, :lists ],
        target:  dom_id(self, :panel),
        partial: "lists/expanded_panel",
        locals:  { list: self }
    end
  end

  SHARE_FIELDS = %w[ share_token share_enabled updated_at ].freeze

  def share_only_update?
    saved_changes.keys.all? { |k| SHARE_FIELDS.include?(k) }
  end

  def broadcast_list_destroyed
    broadcast_remove_to [ user, :lists ], target: dom_id(self)
    broadcast_remove_to [ user, :lists ], target: dom_id(self, :panel)
  end

  def bust_dashboard_cache
    Rails.cache.delete_matched("dashboard/*#{user_id}*")
  end
end
