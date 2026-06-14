class AuditLogsController < ApplicationController
  def index
    @audit_logs = current_user.audit_logs
                               .includes(:auditable)
                               .order(created_at: :desc)

    action_filter = request.query_parameters["action"]
    @audit_logs = @audit_logs.where(action: action_filter)                                   if action_filter.present?
    @audit_logs = @audit_logs.where(origin: params[:origin])                                 if params[:origin].present?
    @audit_logs = @audit_logs.where("created_at >= ?", params[:date_from].to_date)           if params[:date_from].present?
    @audit_logs = @audit_logs.where("created_at <= ?", params[:date_to].to_date.end_of_day)  if params[:date_to].present?

    @audit_logs = @audit_logs.page(params[:page]).per(25)
  end
end
