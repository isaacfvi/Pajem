class Item < ApplicationRecord
  include SoftDeletable
  include Auditable

  belongs_to :list
  belongs_to :user

  PRIORITY_LABELS = {
    "low"    => "Baixa",
    "medium" => "Média",
    "high"   => "Alta",
    nil      => "Sem prioridade"
  }.freeze

  enum :priority, { low: 0, medium: 1, high: 2 }, prefix: true

  validates :title, presence: true, length: { maximum: 255 }
  validates :list, presence: true
  validates :user, presence: true

  scope :overdue, -> { where("due_date < ? AND completed = false", Date.current) }

  after_create_commit  :broadcast_item_created
  after_update_commit  :broadcast_item_updated
  after_destroy_commit :broadcast_item_destroyed
  after_commit         :bust_dashboard_cache

  before_save :manage_completed_at

  private

  def broadcast_item_created
    broadcast_remove_to list, target: "list_empty_#{list_id}"
    broadcast_append_to list,
      target:  "list_items_#{list_id}",
      partial: "items/item",
      locals:  { item: self, list: list }
    broadcast_progress_bars
  end

  def broadcast_item_updated
    if saved_change_to_deleted_at? && discarded?
      broadcast_remove_to list, target: dom_id(self)
    else
      broadcast_replace_to list,
        partial: "items/item",
        locals:  { item: self, list: list }
    end
    broadcast_progress_bars
  end

  def broadcast_item_destroyed
    broadcast_remove_to list, target: dom_id(self)
    broadcast_progress_bars
  end

  def broadcast_progress_bars
    fresh_list = List.unscoped.find_by(id: list_id)
    return unless fresh_list&.kept?
    broadcast_replace_to fresh_list,
      target:  dom_id(fresh_list),
      partial: "lists/postit_card",
      locals:  { list: fresh_list }
    broadcast_replace_to fresh_list,
      target:  "#{dom_id(fresh_list, :progress)}_panel",
      partial: "lists/progress_bar",
      locals:  { list: fresh_list }
  end

  def manage_completed_at
    if completed? && completed_at.nil?
      self.completed_at = Time.current
    elsif !completed?
      self.completed_at = nil
    end
  end

  def bust_dashboard_cache
    Rails.cache.write("dashboard/version/#{user_id}", Time.now.to_i)
  end
end
