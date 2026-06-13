class CreateContexts < ActiveRecord::Migration[8.1]
  def change
    create_table :contexts do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false, limit: 100
      t.timestamps
    end

    add_index :contexts, [:user_id, :name], unique: true
  end
end
