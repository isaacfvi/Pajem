require "test_helper"

class SharesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @alice = User.create!(name: "Alice", email: "alice@test.com", password: "password123456")
    @list  = @alice.lists.create!(title: "Lista Pública", share_token: "tok123", share_enabled: true)
    @private_list = @alice.lists.create!(title: "Lista Privada", share_token: "tok456", share_enabled: false)
  end

  test "GET /c/:token exibe lista compartilhada sem autenticação" do
    get share_path("tok123")
    assert_response :success
    assert_match "Lista Pública", response.body
  end

  test "GET /c/:token usa layout share" do
    get share_path("tok123")
    assert_response :success
    assert_match "noindex, nofollow", response.body
  end

  test "GET /c/:token retorna 404 para token inválido" do
    get share_path("naoexiste")
    assert_response :not_found
  end

  test "GET /c/:token retorna 404 quando compartilhamento está desativado" do
    get share_path("tok456")
    assert_response :not_found
  end

  test "GET /c/:token exibe os itens da lista" do
    @list.items.create!(title: "Item visível", user: @alice)
    get share_path("tok123")
    assert_match "Item visível", response.body
  end

  test "GET /c/:token não exibe itens descartados" do
    item = @list.items.create!(title: "Item excluído", user: @alice)
    item.discard
    get share_path("tok123")
    assert_no_match "Item excluído", response.body
  end
end
