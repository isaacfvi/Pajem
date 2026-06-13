require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "GET /signup renderiza o formulário" do
    get signup_path
    assert_response :success
  end

  test "POST /signup com dados válidos cria usuário e redireciona" do
    assert_difference "User.count" do
      post "/signup", params: { user: {
        name: "Alice",
        email: "alice@example.com",
        password: "password123456",
        password_confirmation: "password123456"
      } }
    end
    assert_redirected_to root_path
    assert_not_nil session[:user_id]
  end

  test "POST /signup com e-mail duplicado re-renderiza com erro" do
    User.create!(name: "Alice", email: "alice@example.com", password: "password123456")
    post "/signup", params: { user: {
      name: "Alice2",
      email: "alice@example.com",
      password: "password123456",
      password_confirmation: "password123456"
    } }
    assert_response :unprocessable_entity
    assert_nil session[:user_id]
  end

  test "POST /signup com senha curta re-renderiza com erro" do
    post "/signup", params: { user: {
      name: "Alice",
      email: "short@example.com",
      password: "curta",
      password_confirmation: "curta"
    } }
    assert_response :unprocessable_entity
    assert_nil session[:user_id]
  end

  test "POST /signup sem nome re-renderiza com erro" do
    post "/signup", params: { user: {
      name: "",
      email: "noname@example.com",
      password: "password123456",
      password_confirmation: "password123456"
    } }
    assert_response :unprocessable_entity
  end

  test "usuário autenticado é redirecionado de GET /signup" do
    User.create!(name: "Alice", email: "alice2@example.com", password: "password123456")
    post "/login", params: { email: "alice2@example.com", password: "password123456" }
    get signup_path
    assert_redirected_to root_path
  end
end
