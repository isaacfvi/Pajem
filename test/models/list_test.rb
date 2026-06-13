require "test_helper"

class ListTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(name: "Alice", email: "alice_list@example.com", password: "password123456")
  end

  test "valid with required attributes" do
    list = List.new(title: "My List", user: @user)
    assert list.valid?
  end

  test "invalid without title" do
    list = List.new(user: @user)
    assert_not list.valid?
    assert_includes list.errors[:title], "can't be blank"
  end

  test "invalid without user" do
    list = List.new(title: "My List")
    assert_not list.valid?
    assert list.errors[:user].any?
  end

  test "title cannot exceed 255 characters" do
    list = List.new(title: "a" * 256, user: @user)
    assert_not list.valid?
    assert list.errors[:title].any?
  end

  test "color can be nil" do
    list = List.new(title: "My List", user: @user, color: nil)
    assert list.valid?
  end

  test "color accepts cores da paleta" do
    List::PALETTE.each do |entry|
      list = List.new(title: "My List", user: @user, color: entry[:bg])
      assert list.valid?, "#{entry[:name]} (#{entry[:bg]}) deveria ser válida"
    end
  end

  test "color rejeita cores fora da paleta" do
    list = List.new(title: "My List", user: @user, color: "#FF5733")
    assert_not list.valid?
    assert list.errors[:color].any?
  end

  test "#progress returns 0 when no items" do
    list = List.create!(title: "Empty List", user: @user)
    assert_equal 0, list.progress
  end

  test "#progress returns percentage of completed items" do
    list = List.create!(title: "Progress List", user: @user)
    list.items.create!(title: "Done", user: @user, completed: true)
    list.items.create!(title: "Not done", user: @user, completed: false)
    assert_equal 50, list.progress
  end

  test "#progress ignores discarded items" do
    list = List.create!(title: "Discard List", user: @user)
    list.items.create!(title: "Done", user: @user, completed: true)
    discarded = list.items.create!(title: "Discarded", user: @user, completed: false)
    discarded.discard
    assert_equal 100, list.progress
  end

  test "#active_items returns only kept items" do
    list = List.create!(title: "Active Items List", user: @user)
    kept = list.items.create!(title: "Kept", user: @user)
    discarded = list.items.create!(title: "Discarded", user: @user)
    discarded.discard
    assert_includes list.active_items, kept
    assert_not_includes list.active_items, discarded
  end

  test "soft delete moves list to discarded scope" do
    list = List.create!(title: "To Delete", user: @user)
    list.discard
    assert list.discarded?
    assert_not List.exists?(list.id)
    assert List.unscoped.exists?(list.id)
  end

  test "kept scope returns only non-deleted lists" do
    active = List.create!(title: "Active", user: @user)
    deleted = List.create!(title: "Deleted", user: @user)
    deleted.discard
    assert_includes List.kept, active
    assert_not_includes List.kept, deleted
  end

  test "discarded scope returns only deleted lists" do
    active = List.create!(title: "Active2", user: @user)
    deleted = List.create!(title: "Deleted2", user: @user)
    deleted.discard
    assert_includes List.discarded, deleted
    assert_not_includes List.discarded, active
  end
end
