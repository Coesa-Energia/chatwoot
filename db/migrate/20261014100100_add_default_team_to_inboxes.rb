class AddDefaultTeamToInboxes < ActiveRecord::Migration[7.1]
  def change
    # Optional team that every new conversation of the inbox starts with.
    add_column :inboxes, :default_team_id, :bigint
    add_index :inboxes, :default_team_id
  end
end
