require "test_helper"

class ContextTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(name: "Alice", email: "alice_ctx@example.com", password: "password123456")
  end

  test "valid with required attributes" do
    context = Context.new(name: "Work", user: @user)
    assert context.valid?
  end

  test "invalid without name" do
    context = Context.new(user: @user)
    assert_not context.valid?
    assert_includes context.errors[:name], "can't be blank"
  end

  test "invalid without user" do
    context = Context.new(name: "Work")
    assert_not context.valid?
    assert context.errors[:user].any?
  end

  test "name cannot exceed 100 characters" do
    context = Context.new(name: "a" * 101, user: @user)
    assert_not context.valid?
    assert context.errors[:name].any?
  end

  test "name is unique scoped to user_id" do
    Context.create!(name: "Work", user: @user)
    duplicate = Context.new(name: "Work", user: @user)
    assert_not duplicate.valid?
    assert duplicate.errors[:name].any?
  end

  test "same name is allowed for different users" do
    other_user = User.create!(name: "Bob", email: "bob_ctx@example.com", password: "password123456")
    Context.create!(name: "Work", user: @user)
    context = Context.new(name: "Work", user: other_user)
    assert context.valid?
  end
end
