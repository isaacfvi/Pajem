class ItemsController < ApplicationController
  before_action :set_list
  before_action :set_item, only: [ :show, :edit, :update, :destroy, :toggle ]

  def index
    scope = @list.items.kept
    scope = scope.where("title ILIKE ?", "%#{params[:q]}%") if params[:q].present?

    scope = case params[:status]
    when "pending" then scope.where(completed: false)
    when "done"    then scope.where(completed: true)
    else scope
    end

    scope = scope.where(priority: params[:priority]) if params[:priority].present?

    scope = case params[:due]
    when "overdue" then scope.where("due_date < ?", Date.today)
    when "today"   then scope.where(due_date: Date.today)
    when "week"    then scope.where(due_date: Date.today..Date.today.end_of_week)
    else scope
    end

    @items = scope.order(completed: :asc, created_at: :asc)
  end

  def create
    @item = @list.items.build(item_params)
    @item.user = current_user
    if @item.save
      AuditLog.record(user: current_user, action: "created", auditable: @item, origin: "manual")
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to lists_path, notice: "Item criado." }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "new_item_form_#{@list.id}",
            partial: "items/new_form",
            locals: { item: @item, list: @list }
          ), status: :unprocessable_entity
        end
        format.html { redirect_to lists_path, alert: @item.errors.full_messages.to_sentence }
      end
    end
  end

  def show; end

  def edit; end

  def update
    if @item.update(item_params)
      AuditLog.record(user: current_user, action: "updated", auditable: @item, origin: "manual", changes: @item.saved_changes)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to lists_path, notice: "Item atualizado." }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @item.discard
    AuditLog.record(user: current_user, action: "deleted", auditable: @item, origin: "manual")
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to lists_path }
    end
  end

  def toggle
    new_completed = !@item.completed
    action = new_completed ? "completed" : "uncompleted"
    @item.update!(completed: new_completed)
    AuditLog.record(user: current_user, action: action, auditable: @item, origin: "manual")
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to lists_path }
    end
  end

  private

  def set_list
    @list = current_user.lists.kept.find(params[:list_id])
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  def set_item
    @item = @list.items.kept.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  def item_params
    p = params.require(:item).permit(:title, :description, :due_date, :priority)
    p[:priority] = nil if p[:priority].blank?
    p
  end
end
