class AddAiOnlyToArticles < ActiveRecord::Migration[7.2]
  def change
    add_column :articles, :ai_only, :boolean, default: false, null: false
  end
end
