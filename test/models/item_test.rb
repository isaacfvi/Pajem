require "test_helper"

class ItemTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(name: "Alice", email: "alice_item@example.com", password: "password123456")
    @list = List.create!(title: "My List", user: @user)
  end

  test "valid with required attributes" do
    item = Item.new(title: "Task", user: @user, list: @list)
    assert item.valid?
  end

  test "invalid without title" do
    item = Item.new(user: @user, list: @list)
    assert_not item.valid?
    assert_includes item.errors[:title], "can't be blank"
  end

  test "invalid without list" do
    item = Item.new(title: "Task", user: @user)
    assert_not item.valid?
    assert item.errors[:list].any?
  end

  test "invalid without user" do
    item = Item.new(title: "Task", list: @list)
    assert_not item.valid?
    assert item.errors[:user].any?
  end

  test "title cannot exceed 255 characters" do
    item = Item.new(title: "a" * 256, user: @user, list: @list)
    assert_not item.valid?
    assert item.errors[:title].any?
  end

  test "priority enum methods work with prefix" do
    item = Item.create!(title: "Task", user: @user, list: @list, priority: :high)
    assert item.priority_high?
    assert_not item.priority_low?
    assert_not item.priority_medium?
  end

  test "priority can be nil" do
    item = Item.new(title: "Task", user: @user, list: @list)
    assert item.valid?
    assert_nil item.priority
  end

  test "sets completed_at when marking as completed" do
    item = Item.create!(title: "Task", user: @user, list: @list)
    assert_nil item.completed_at
    item.update!(completed: true)
    assert_not_nil item.completed_at
  end

  test "clears completed_at when unmarking as completed" do
    item = Item.create!(title: "Task", user: @user, list: @list)
    item.update!(completed: true)
    item.update!(completed: false)
    assert_nil item.completed_at
  end

  test "does not overwrite completed_at if already set" do
    fixed_time = 1.hour.ago
    item = Item.create!(title: "Task", user: @user, list: @list, completed: true, completed_at: fixed_time)
    assert_in_delta fixed_time.to_i, item.completed_at.to_i, 1
  end

  test "overdue scope returns items with past due_date that are not completed" do
    overdue = Item.create!(title: "Overdue", user: @user, list: @list, due_date: 1.day.ago, completed: false)
    future = Item.create!(title: "Future", user: @user, list: @list, due_date: 1.day.from_now, completed: false)
    done = Item.create!(title: "Done", user: @user, list: @list, due_date: 1.day.ago, completed: true)
    assert_includes Item.overdue, overdue
    assert_not_includes Item.overdue, future
    assert_not_includes Item.overdue, done
  end

  test "soft delete moves item to discarded scope" do
    item = Item.create!(title: "To Delete", user: @user, list: @list)
    item.discard
    assert item.discarded?
    assert_not Item.exists?(item.id)
    assert Item.unscoped.exists?(item.id)
  end

  test "kept scope returns only non-deleted items" do
    active = Item.create!(title: "Active", user: @user, list: @list)
    deleted = Item.create!(title: "Deleted", user: @user, list: @list)
    deleted.discard
    assert_includes Item.kept, active
    assert_not_includes Item.kept, deleted
  end

  test "discarded scope returns only deleted items" do
    active = Item.create!(title: "Active2", user: @user, list: @list)
    deleted = Item.create!(title: "Deleted2", user: @user, list: @list)
    deleted.discard
    assert_includes Item.discarded, deleted
    assert_not_includes Item.discarded, active
  end
end
