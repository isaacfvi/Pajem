require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = User.create!(name: "Alice", email: "alice@example.com", password: "password123456")
  end

  test "GET /login renderiza o formulário" do
    get login_path
    assert_response :success
  end

  test "POST /login com credenciais válidas seta sessão e redireciona" do
    post "/login", params: { email: "alice@example.com", password: "password123456" }
    assert_redirected_to root_path
    assert_equal @user.id, session[:user_id]
  end

  test "POST /login com senha errada re-renderiza com erro genérico" do
    post "/login", params: { email: "alice@example.com", password: "senhaerrada" }
    assert_response :unprocessable_entity
    assert_nil session[:user_id]
  end

  test "POST /login com e-mail inexistente re-renderiza com erro genérico" do
    post "/login", params: { email: "naoexiste@example.com", password: "password123456" }
    assert_response :unprocessable_entity
    assert_nil session[:user_id]
  end

  test "POST /login com conta descartada re-renderiza com erro genérico" do
    @user.discard
    post "/login", params: { email: "alice@example.com", password: "password123456" }
    assert_response :unprocessable_entity
    assert_nil session[:user_id]
  end

  test "DELETE /logout limpa sessão e redireciona para login" do
    post "/login", params: { email: "alice@example.com", password: "password123456" }
    delete logout_path
    assert_redirected_to login_path
    assert_nil session[:user_id]
  end

  test "usuário autenticado é redirecionado de GET /login" do
    post "/login", params: { email: "alice@example.com", password: "password123456" }
    get login_path
    assert_redirected_to root_path
  end

  test "require_login redireciona visitante e salva return_to" do
    get root_path
    assert_redirected_to login_path
    assert_equal "/", session[:return_to]
  end

  test "após login redireciona para return_to salvo na sessão" do
    get root_path
    post "/login", params: { email: "alice@example.com", password: "password123456" }
    assert_redirected_to "/"
  end
end
