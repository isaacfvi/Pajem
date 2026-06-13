class CreateItems < ActiveRecord::Migration[8.1]
  def change
    create_table :items do |t|
      t.references :list, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :title, null: false, limit: 255
      t.text :description
      t.boolean :completed, null: false, default: false
      t.datetime :completed_at
      t.date :due_date
      t.integer :priority
      t.datetime :deleted_at
      t.timestamps
    end

    add_index :items, :deleted_at

    execute <<~SQL
      CREATE INDEX idx_items_list_active
        ON items(list_id, deleted_at);

      CREATE INDEX idx_items_list_priority
        ON items(list_id, priority)
        WHERE deleted_at IS NULL;

      CREATE INDEX idx_items_overdue_active
        ON items(user_id, due_date)
        WHERE due_date IS NOT NULL AND deleted_at IS NULL AND completed = false;

      CREATE INDEX idx_items_title_trgm
        ON items USING gin (title gin_trgm_ops);
    SQL
  end
end
