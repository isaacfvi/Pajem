class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :require_login
  before_action :load_sidebar_data, if: :user_signed_in?

  helper_method :current_user, :user_signed_in?

  private

  def current_user
    @current_user ||= User.kept.find_by(id: session[:user_id])
  end

  def user_signed_in?
    current_user.present?
  end

  def require_login
    return if user_signed_in?

    session[:return_to] = request.fullpath
    redirect_to login_path, alert: "Você precisa estar logado para acessar esta página."
  end

  def require_no_login
    redirect_to root_path if user_signed_in?
  end

  def load_sidebar_data
    @sidebar_contexts = current_user.contexts.order(:name)
  end
end
