require "test_helper"

class ChatMessageTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(name: "Alice", email: "alice_chat@example.com", password: "password123456")
  end

  test "valid with required attributes" do
    msg = ChatMessage.new(user: @user, role: "user", content: "Hello!")
    assert msg.valid?
  end

  test "accepts assistant role" do
    msg = ChatMessage.new(user: @user, role: "assistant", content: "Olá!")
    assert msg.valid?
  end

  test "invalid without role" do
    msg = ChatMessage.new(user: @user, content: "Hello!")
    assert_not msg.valid?
    assert msg.errors[:role].any?
  end

  test "invalid with unrecognized role" do
    msg = ChatMessage.new(user: @user, role: "admin", content: "Hello!")
    assert_not msg.valid?
    assert msg.errors[:role].any?
  end

  test "invalid without content" do
    msg = ChatMessage.new(user: @user, role: "user")
    assert_not msg.valid?
    assert msg.errors[:content].any?
  end

  test "invalid without user" do
    msg = ChatMessage.new(role: "user", content: "Hello!")
    assert_not msg.valid?
    assert msg.errors[:user].any?
  end
end
