class DashboardController < ApplicationController
  def index
    @lists_count     = current_user.lists.kept.count
    @pending_count   = current_user.items.kept.where(completed: false).count
    @completed_count = current_user.items.kept.where(completed: true).count
    @overdue_count   = current_user.items.kept
                                   .where(completed: false)
                                   .where("due_date < ?", Date.today).count

    @completed_by_day = current_user.items.kept
                                    .where(completed: true)
                                    .group_by_day(:completed_at, range: 6.days.ago..Time.now)
                                    .count

    @items_by_priority = current_user.items.kept
                                     .where(completed: false)
                                     .group(:priority)
                                     .count
                                     .transform_keys { |k| Item::PRIORITY_LABELS[k] || "Sem prioridade" }

    @progress_by_context = build_context_progress

    @upcoming_items = current_user.items.kept
                                  .where(completed: false)
                                  .where.not(due_date: nil)
                                  .includes(:list)
                                  .order(due_date: :asc)
                                  .limit(10)

    @recent_activity = current_user.audit_logs
                                   .includes(:auditable)
                                   .order(created_at: :desc)
                                   .limit(10)
  end

  private

  def build_context_progress
    current_user.contexts
      .joins(lists: :items)
      .where(items: { deleted_at: nil })
      .group("contexts.id", "contexts.name")
      .select(
        "contexts.name",
        "COUNT(items.id) AS total",
        "SUM(CASE WHEN items.completed THEN 1 ELSE 0 END) AS completed_count"
      )
      .map { |r| [ r.name, r.total > 0 ? (r.completed_count.to_f / r.total * 100).round : 0 ] }
      .to_h
  end
end
