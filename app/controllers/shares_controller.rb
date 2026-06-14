class SharesController < ApplicationController
  skip_before_action :require_login

  def show
    @list = List.find_by(share_token: params[:token], share_enabled: true)
    return head :not_found unless @list

    @items = @list.items.kept.order(completed: :asc, created_at: :asc)
    render layout: "share"
  end
end
