# Which members of an inbox see every conversation and which only their own (InboxMember#see_all_conversations).
# See Inboxes::ConversationAccess for the rule itself.
module InboxConversationAccess
  extend ActiveSupport::Concern

  # Sets which members see every conversation of the inbox (the others only see their own).
  # @param user_ids [Array<Integer>] members that may see all conversations
  def update_conversation_access(user_ids)
    ids = Array(user_ids).map(&:to_i)
    changed_ids = inbox_members.where(user_id: ids, see_all_conversations: false).pluck(:user_id) +
                  inbox_members.where.not(user_id: ids).where(see_all_conversations: true).pluck(:user_id)
    inbox_members.where(id: inbox_members.where(user_id: changed_ids)).find_each do |member|
      member.update!(see_all_conversations: ids.include?(member.user_id))
    end
  end

  # Sets which members take part in the automatic assignment (round robin) of the inbox. The others keep access
  # to the inbox but are never picked by auto assignment; manual assignment still works for them.
  # @param user_ids [Array<Integer>] members that stay in the rotation
  def update_rotation(user_ids)
    ids = Array(user_ids).map(&:to_i)
    inbox_members.where(user_id: ids, in_rotation: false).update_all(in_rotation: true) # rubocop:disable Rails/SkipsModelValidations
    inbox_members.where.not(user_id: ids).where(in_rotation: true).update_all(in_rotation: false) # rubocop:disable Rails/SkipsModelValidations
  end

  # Ids of the members that auto assignment may pick.
  def rotation_member_ids
    inbox_members.where(in_rotation: true).pluck(:user_id)
  end

  # Members that may be told about this conversation: those who see the whole inbox, the assignee and the
  # participants. Administrators are added separately by the callers.
  def members_with_access_to(conversation)
    allowed_ids = inbox_members.where(see_all_conversations: true).pluck(:user_id)
    allowed_ids << conversation.assignee_id
    allowed_ids.concat(conversation.conversation_participants.pluck(:user_id))
    members.where(id: allowed_ids.compact.uniq)
  end
end
