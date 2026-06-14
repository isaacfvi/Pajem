class TrashController < ApplicationController
  before_action :set_list, only: [ :restore_list, :destroy_list ]
  before_action :set_item, only: [ :restore_item, :destroy_item ]

  def index
    @discarded_lists = current_user.lists.discarded.order(deleted_at: :desc)
    @discarded_items = current_user.items.discarded.order(deleted_at: :desc)

    parent_list_ids = @discarded_items.map(&:list_id).uniq.compact
    @parent_lists_by_id = List.unscoped.where(id: parent_list_ids).index_by(&:id)
  end

  def restore_list
    @list.undiscard
    AuditLog.record(user: current_user, action: "restored", auditable: @list, origin: "manual")
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove("trash_list_#{@list.id}"),
          turbo_stream.update("trash-lists-count", current_user.lists.discarded.count.to_s)
        ]
      end
      format.html { redirect_to trash_path, notice: "Lista restaurada com sucesso." }
    end
  end

  def restore_item
    parent_list = List.unscoped.find_by(id: @item.list_id)
    if parent_list&.discarded?
      return redirect_to trash_path,
        alert: "Restaure a lista '#{parent_list.title}' antes de restaurar este item."
    end

    @item.undiscard
    AuditLog.record(user: current_user, action: "restored", auditable: @item, origin: "manual")
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove("trash_item_#{@item.id}"),
          turbo_stream.update("trash-items-count", current_user.items.discarded.count.to_s)
        ]
      end
      format.html { redirect_to trash_path, notice: "Item restaurado com sucesso." }
    end
  end

  def destroy_list
    @list.destroy
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove("trash_list_#{@list.id}"),
          turbo_stream.update("trash-lists-count", current_user.lists.discarded.count.to_s)
        ]
      end
      format.html { redirect_to trash_path, notice: "Lista excluída permanentemente." }
    end
  end

  def destroy_item
    @item.destroy
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove("trash_item_#{@item.id}"),
          turbo_stream.update("trash-items-count", current_user.items.discarded.count.to_s)
        ]
      end
      format.html { redirect_to trash_path, notice: "Item excluído permanentemente." }
    end
  end

  private

  def set_list
    @list = current_user.lists.discarded.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  def set_item
    @item = current_user.items.discarded.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end
end
