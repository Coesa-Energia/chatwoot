class AddInboxIdsToDashboardApps < ActiveRecord::Migration[7.1]
  def change
    # Inboxes whose conversations show the app; empty means every inbox (the behaviour before this column).
    add_column :dashboard_apps, :inbox_ids, :bigint, array: true, default: [], null: false
  end
end
