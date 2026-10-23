class CreateConversationUserStates < ActiveRecord::Migration[7.1]
  # Per-user state of a conversation, like the WhatsApp app's pinned and archived chats:
  # what one agent pins or archives does not change the list of the others.
  def change
    create_table :conversation_user_states do |t|
      t.bigint :account_id, null: false
      t.bigint :user_id, null: false
      t.bigint :conversation_id, null: false
      t.datetime :pinned_at
      t.datetime :archived_at
      t.timestamps
    end

    add_index :conversation_user_states, [:user_id, :conversation_id], unique: true
    add_index :conversation_user_states, :conversation_id
    add_index :conversation_user_states, :account_id
  end
end
