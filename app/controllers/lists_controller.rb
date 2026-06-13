class ListsController < ApplicationController
  def index
    @lists = current_user.lists.kept.includes(:items, :context)
    @lists = @lists.where(context_id: params[:context_id]) if params[:context_id].present?
    @active_context = current_user.contexts.find_by(id: params[:context_id])
  end
end
