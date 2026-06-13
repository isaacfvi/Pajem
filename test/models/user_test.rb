require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "valid with required attributes" do
    user = User.new(name: "Test User", email: "test@example.com", password: "password123456")
    assert user.valid?
  end

  test "invalid without name" do
    user = User.new(email: "test@example.com", password: "password123456")
    assert_not user.valid?
    assert_includes user.errors[:name], "can't be blank"
  end

  test "invalid without email" do
    user = User.new(name: "Test", password: "password123456")
    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "invalid with malformed email" do
    user = User.new(name: "Test", email: "not-an-email", password: "password123456")
    assert_not user.valid?
    assert user.errors[:email].any?
  end

  test "invalid with duplicate email (case-insensitive)" do
    User.create!(name: "Alice", email: "alice@example.com", password: "password123456")
    user = User.new(name: "Alice2", email: "ALICE@example.com", password: "password123456")
    assert_not user.valid?
    assert user.errors[:email].any?
  end

  test "normalizes email to downcase before save" do
    user = User.create!(name: "Test", email: "Test@Example.COM", password: "password123456")
    assert_equal "test@example.com", user.email
  end

  test "invalid with password shorter than 8 characters" do
    user = User.new(name: "Test", email: "short@example.com", password: "abc123")
    assert_not user.valid?
    assert user.errors[:password].any?
  end

  test "allows update without providing password" do
    user = User.create!(name: "Test", email: "update@example.com", password: "password123456")
    user.name = "Updated Name"
    assert user.valid?
  end

  test "authenticates with correct password" do
    user = User.create!(name: "Auth", email: "auth@example.com", password: "password123456")
    assert user.authenticate("password123456")
  end

  test "does not authenticate with wrong password" do
    user = User.create!(name: "Auth", email: "auth2@example.com", password: "password123456")
    assert_not user.authenticate("wrongpassword")
  end

  test "soft delete keeps record in database" do
    user = User.create!(name: "Soft", email: "soft@example.com", password: "password123456")
    user.discard
    assert user.discarded?
    assert User.unscoped.exists?(user.id)
    assert_not User.exists?(user.id)
  end

  test "#active? returns true for non-deleted user" do
    user = User.create!(name: "Active", email: "active@example.com", password: "password123456")
    assert user.active?
  end

  test "#active? returns false for discarded user" do
    user = User.create!(name: "Inactive", email: "inactive@example.com", password: "password123456")
    user.discard
    assert_not user.active?
  end

  test "default scope excludes discarded users" do
    user = User.create!(name: "Hidden", email: "hidden@example.com", password: "password123456")
    user.discard
    assert_not User.where(email: "hidden@example.com").exists?
  end
end
