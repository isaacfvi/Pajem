class DashboardController < ApplicationController
  def index
    cache_version = Rails.cache.read("dashboard/version/#{current_user.id}") || 0

    stats = Rails.cache.fetch([ "dashboard/stats", current_user.id, cache_version ], expires_in: 5.minutes) do
      {
        lists_count:         current_user.lists.kept.count,
        pending_count:       current_user.items.kept.where(completed: false).count,
        completed_count:     current_user.items.kept.where(completed: true).count,
        overdue_count:       current_user.items.kept.where(completed: false).where("due_date < ?", Date.today).count,
        progress_by_context: build_context_progress
      }
    end

    @lists_count          = stats[:lists_count]
    @pending_count        = stats[:pending_count]
    @completed_count      = stats[:completed_count]
    @overdue_count        = stats[:overdue_count]
    @progress_by_context  = stats[:progress_by_context]

    @chart_period = (params[:period] || 7).to_i.clamp(1, 90)
    @completed_by_day = Rails.cache.fetch([ "dashboard/chart", current_user.id, @chart_period, cache_version ], expires_in: 5.minutes) do
      current_user.items.kept
                  .where(completed: true)
                  .group_by_day(:completed_at, range: (@chart_period - 1).days.ago..Time.now)
                  .count
    end

    context_scope = if params[:chart_context_id].present?
                      current_user.items.kept
                                  .joins(:list)
                                  .where(lists: { context_id: params[:chart_context_id] })
    else
      current_user.items.kept
    end

    @items_by_priority = context_scope
                           .where(completed: false)
                           .group(:priority)
                           .count
                           .transform_keys { |k| Item::PRIORITY_LABELS[k] || "Sem prioridade" }

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
