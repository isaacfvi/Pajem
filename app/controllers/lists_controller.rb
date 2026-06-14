class ListsController < ApplicationController
  before_action :set_list, only: [ :edit, :update, :destroy, :compartilhar, :revogar_link ]

  def index
    @active_context = current_user.contexts.find_by(id: params[:context_id])
    scope = current_user.lists.kept.includes(:context, :items)
    scope = scope.where("title ILIKE ?", "%#{params[:q]}%") if params[:q].present?
    scope = scope.where(context_id: @active_context.id)    if @active_context
    @lists = scope.order(created_at: :desc)
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

  def compartilhar
    if @list.share_enabled?
      @list.update!(share_enabled: false)
      AuditLog.record(user: current_user, action: "unshared", auditable: @list, origin: "manual")
    else
      @list.share_token ||= SecureRandom.urlsafe_base64(16)
      @list.share_enabled = true
      @list.save!
      AuditLog.record(user: current_user, action: "shared", auditable: @list, origin: "manual")
    end
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to lists_path }
    end
  end

  def revogar_link
    @list.update!(share_token: SecureRandom.urlsafe_base64(16), share_enabled: true)
    AuditLog.record(user: current_user, action: "shared", auditable: @list, origin: "manual")
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to lists_path }
    end
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
