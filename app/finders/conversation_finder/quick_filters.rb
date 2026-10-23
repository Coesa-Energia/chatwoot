# Quick filters of the conversation list (unread, awaiting reply, archived) and the per-agent pinned
# ordering. Mixed into ConversationFinder, which owns @conversations, params and current_user.
module ConversationFinder::QuickFilters
  private

  # The current agent's pinned/archived state (conversation_user_states has at most one row per agent
  # and conversation, so the LEFT JOIN never duplicates conversations).
  def join_user_state
    # A bot has no pinned/archived state, and its id may collide with a user's: join no row for it.
    user_id = current_user.is_a?(User) ? current_user.id.to_i : 0
    @conversations = @conversations.joins(
      'LEFT JOIN conversation_user_states ON conversation_user_states.conversation_id = conversations.id ' \
      "AND conversation_user_states.user_id = #{user_id}"
    )
  end

  # Archived conversations are hidden from the list and stay hidden, new messages included, until the agent
  # unarchives them. params[:archived] shows only those.
  def filter_by_archived
    @conversations = if ActiveModel::Type::Boolean.new.cast(params[:archived])
                       @conversations.where.not(conversation_user_states: { archived_at: nil })
                     else
                       @conversations.where(conversation_user_states: { archived_at: nil })
                     end
  end

  # Pinned conversations always come first (newest pin first); the chosen sort applies within each group.
  def pinned_first(scope)
    scope.reorder(
      Arel.sql('(conversation_user_states.pinned_at IS NULL) ASC, conversation_user_states.pinned_at DESC'),
      *scope.order_values
    )
  end

  # Same definition of "unread" as Conversation#unread_messages: incoming messages created after the
  # agent last saw the conversation (every incoming message when the agent never opened it).
  def filter_by_unread
    return unless ActiveModel::Type::Boolean.new.cast(params[:unread])

    @conversations = @conversations.where(
      'EXISTS (SELECT 1 FROM messages WHERE messages.conversation_id = conversations.id ' \
      'AND messages.account_id = conversations.account_id AND messages.message_type = :incoming ' \
      'AND (conversations.agent_last_seen_at IS NULL OR messages.created_at > conversations.agent_last_seen_at))',
      incoming: Message.message_types[:incoming]
    )
  end

  # The customer is waiting for an answer: waiting_since is set when the customer writes and cleared
  # when an agent or bot replies (or the conversation is resolved).
  def filter_by_awaiting_reply
    return unless ActiveModel::Type::Boolean.new.cast(params[:awaiting_reply])

    @conversations = @conversations.where.not(waiting_since: nil)
  end
end
