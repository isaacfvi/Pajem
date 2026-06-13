class ContextsController < ApplicationController
  before_action :set_context, only: [ :edit, :update, :destroy ]

  def new
    @context = current_user.contexts.build
  end

  def create
    @context = current_user.contexts.build(context_params)
    if @context.save
      AuditLog.record(user: current_user, action: "created", auditable: @context)
      redirect_to lists_path(context_id: @context.id), notice: "Contexto \"#{@context.name}\" criado."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @context.update(context_params)
      AuditLog.record(user: current_user, action: "updated", auditable: @context)
      redirect_to lists_path(context_id: @context.id), notice: "Contexto \"#{@context.name}\" atualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    name = @context.name
    @context.lists.discard_all if params[:delete_lists] == "true"
    @context.destroy
    AuditLog.record(user: current_user, action: "deleted", auditable: @context)
    redirect_to lists_path, notice: "Workspace \"#{name}\" excluído."
  end

  private

  def set_context
    @context = current_user.contexts.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  def context_params
    params.require(:context).permit(:name)
  end
end
