class ListsController < ApplicationController
  def index
    @lists = current_user.lists.kept.includes(:items)
  end
end
