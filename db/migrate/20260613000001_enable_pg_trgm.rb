class EnablePgTrgm < ActiveRecord::Migration[8.1]
  def up
    enable_extension "pg_trgm"
  end

  def down
    disable_extension "pg_trgm"
  end
end
