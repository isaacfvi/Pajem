class CreateAuditLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_logs do |t|
      t.references :user, null: true, foreign_key: { on_delete: :nullify }, index: false
      t.string :auditable_type, null: false, limit: 50
      t.bigint :auditable_id, null: false
      t.string :action, null: false, limit: 50
      t.string :origin, null: false, limit: 20, default: "manual"
      t.jsonb :changes
      t.datetime :created_at, null: false
    end

    execute <<~SQL
      CREATE INDEX idx_audit_logs_user_recent
        ON audit_logs(user_id, created_at DESC);

      CREATE INDEX idx_audit_logs_auditable
        ON audit_logs(auditable_type, auditable_id);
    SQL
  end
end
