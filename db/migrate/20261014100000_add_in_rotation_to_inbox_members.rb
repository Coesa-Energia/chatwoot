class AddInRotationToInboxMembers < ActiveRecord::Migration[7.1]
  def change
    # Agents that take part in the inbox's automatic assignment (round robin). Everyone stays in it by default,
    # so existing inboxes keep working as before; a member can be switched out to have access without being assigned chats.
    add_column :inbox_members, :in_rotation, :boolean, default: true, null: false
  end
end
