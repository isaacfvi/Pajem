require "test_helper"

class AuditLogTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(name: "Alice", email: "alice_audit@example.com", password: "password123456")
    @list = List.create!(title: "My List", user: @user)
  end

  test "AuditLog.record creates a record" do
    assert_difference "AuditLog.count" do
      AuditLog.record(user: @user, action: "created", auditable: @list)
    end
  end

  test "AuditLog.record sets correct attributes" do
    log = AuditLog.record(user: @user, action: "updated", auditable: @list, origin: "assistant")
    assert_equal @user, log.user
    assert_equal "updated", log.action
    assert_equal @list, log.auditable
    assert_equal "assistant", log.origin
  end

  test "AuditLog.record defaults origin to manual" do
    log = AuditLog.record(user: @user, action: "created", auditable: @list)
    assert_equal "manual", log.origin
  end

  test "AuditLog.record stores changeset column" do
    log = AuditLog.record(user: @user, action: "updated", auditable: @list, changes: { "title" => [ "old", "new" ] })
    log.reload
    assert_equal ["old", "new"], log.changeset["title"]
  end

  test "AuditLog.record does not raise exception on invalid data" do
    assert_nothing_raised do
      result = AuditLog.record(user: @user, action: "invalid_action", auditable: @list)
      assert_not result.persisted?
    end
  end

  test "invalid without action" do
    log = AuditLog.new(user: @user, auditable: @list, origin: "manual")
    assert_not log.valid?
    assert log.errors[:action].any?
  end

  test "invalid with unrecognized action" do
    log = AuditLog.new(user: @user, auditable: @list, action: "hacked", origin: "manual")
    assert_not log.valid?
    assert log.errors[:action].any?
  end

  test "invalid with unrecognized origin" do
    log = AuditLog.new(user: @user, auditable: @list, action: "created", origin: "robot")
    assert_not log.valid?
    assert log.errors[:origin].any?
  end

  test "user can be nil" do
    log = AuditLog.new(auditable: @list, action: "created", origin: "manual")
    assert log.valid?
  end

  test "all valid actions are accepted" do
    AuditLog::VALID_ACTIONS.each do |action|
      log = AuditLog.new(auditable: @list, action: action, origin: "manual")
      assert log.valid?, "Expected '#{action}' to be a valid action"
    end
  end
end
