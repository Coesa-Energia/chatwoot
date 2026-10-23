class AddSeeAllConversationsToInboxMembers < ActiveRecord::Migration[7.1]
  # An agent added to an inbox only sees the conversations assigned to them or where they take part,
  # unless this flag is set for that inbox. Administrators always see everything.
  # Members that already exist keep seeing every conversation, so deploying this changes nothing
  # until someone restricts an agent.
  def up
    add_column :inbox_members, :see_all_conversations, :boolean, default: false, null: false
    execute 'UPDATE inbox_members SET see_all_conversations = TRUE'
  end

  def down
    remove_column :inbox_members, :see_all_conversations
  end
end
