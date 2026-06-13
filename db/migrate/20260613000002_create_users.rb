class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :name, null: false, limit: 255
      t.string :email, null: false, limit: 255
      t.string :password_digest, null: false, limit: 255
      t.string :reset_password_token, limit: 255
      t.datetime :reset_password_sent_at
      t.datetime :deleted_at
      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :deleted_at

    execute <<~SQL
      CREATE UNIQUE INDEX idx_users_reset_password_token
        ON users(reset_password_token)
        WHERE reset_password_token IS NOT NULL;
    SQL
  end
end
