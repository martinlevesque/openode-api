class AddValidIndexToWebsites < ActiveRecord::Migration[5.2]
  def change
    add_index :websites, :valid if ENV["DO_MIGRATIONS"]
  end
end
