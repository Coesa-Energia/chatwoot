# Which conversations an agent may see inside the inboxes they belong to.
#
# An inbox member either sees every conversation of the inbox (InboxMember#see_all_conversations) or only the
# ones assigned to them or where they are a participant (a mention or a manual "add participant" counts).
# Administrators are never restricted. Team access is a separate grant and is not affected.
class Inboxes::ConversationAccess
  # Ids of the account's inboxes where the user is a member restricted to their own conversations.
  def self.restricted_inbox_ids(user:, account:)
    InboxMember.joins(:inbox)
               .where(user_id: user.id, see_all_conversations: false, inboxes: { account_id: account.id })
               .pluck(:inbox_id)
  end

  # Conversations (from `scope`) that the user may see, given the inboxes they are restricted in.
  def self.apply(scope, user:, account:)
    restricted = restricted_inbox_ids(user: user, account: account)
    return scope if restricted.empty?

    participating = ConversationParticipant.where(account_id: account.id, user_id: user.id).select(:conversation_id)
    scope.where.not(inbox_id: restricted)
         .or(scope.where(inbox_id: restricted).where(assignee_id: user.id))
         .or(scope.where(inbox_id: restricted, id: participating))
  end
end
