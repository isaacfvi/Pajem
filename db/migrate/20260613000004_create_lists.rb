class CreateLists < ActiveRecord::Migration[8.1]
  def change
    create_table :lists do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :context, null: true, foreign_key: { on_delete: :nullify }
      t.string :title, null: false, limit: 255
      t.text :description
      t.string :color, limit: 7
      t.string :share_token, limit: 255
      t.boolean :share_enabled, null: false, default: false
      t.datetime :deleted_at
      t.timestamps
    end

    add_index :lists, :deleted_at

    execute <<~SQL
      CREATE UNIQUE INDEX idx_lists_share_token
        ON lists(share_token)
        WHERE share_token IS NOT NULL;

      CREATE INDEX idx_lists_title_trgm
        ON lists USING gin (title gin_trgm_ops);
    SQL
  end
end
