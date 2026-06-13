class RenameChangesToChangesetInAuditLogs < ActiveRecord::Migration[8.1]
  def change
    rename_column :audit_logs, :changes, :changeset
  end
end
