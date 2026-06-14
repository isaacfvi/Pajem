class ListsController < ApplicationController
  before_action :set_list, only: [ :edit, :update, :destroy ]

  def index
    @active_context = current_user.contexts.find_by(id: params[:context_id])
    @lists = current_user.lists.kept.includes(:items, :context)
    @lists = @lists.where(context_id: @active_context.id) if @active_context
  end

  def new
    @list = current_user.lists.build
  end

  def create
    @list = current_user.lists.build(list_params)
    if @list.save
      AuditLog.record(user: current_user, action: "created", auditable: @list, origin: "manual")
      redirect_to lists_path, notice: "Lista \"#{@list.title}\" criada."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @list.update(list_params)
      AuditLog.record(user: current_user, action: "updated", auditable: @list, origin: "manual", changes: @list.saved_changes)
      redirect_to lists_path, notice: "Lista \"#{@list.title}\" atualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    title = @list.title
    @list.discard
    AuditLog.record(user: current_user, action: "deleted", auditable: @list, origin: "manual")
    redirect_to lists_path, notice: "Lista \"#{title}\" excluída."
  end

  private

  def set_list
    @list = current_user.lists.kept.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  def list_params
    p = params.require(:list).permit(:title, :description, :color, :context_id)
    p[:color] = nil if p[:color].blank?
    p[:context_id] = nil if p[:context_id].blank?
    p
  end
end
