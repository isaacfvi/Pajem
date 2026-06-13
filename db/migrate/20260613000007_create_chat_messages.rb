class CreateChatMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :chat_messages do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :role, null: false, limit: 20
      t.text :content, null: false
      t.jsonb :metadata
      t.datetime :created_at, null: false
    end

    add_index :chat_messages, :created_at
  end
end
