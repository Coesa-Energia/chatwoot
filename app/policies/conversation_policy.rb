class ConversationPolicy < ApplicationPolicy
  def index?
    true
  end

  def destroy?
    administrator?
  end

  def show?
    administrator? || agent_bot? || agent_can_view_conversation?
  end

  private

  def agent_can_view_conversation?
    inbox_access? || team_access?
  end

  def administrator?
    account_user&.administrator?
  end

  def agent_bot?
    user.is_a?(AgentBot)
  end

  # An inbox member sees every conversation of the inbox only when allowed to (see Inboxes::ConversationAccess);
  # otherwise only the conversations assigned to them or where they take part.
  def inbox_access?
    member = InboxMember.joins(:inbox).find_by(user_id: user.id, inbox_id: record.inbox_id, inboxes: { account_id: account&.id })
    return false if member.blank?

    member.see_all_conversations? || assigned_to_user? || participant?
  end

  def team_access?
    return false if record.team_id.blank?

    user.teams.where(account_id: account&.id).exists?(id: record.team_id)
  end

  def assigned_to_user?
    record.assignee_id == user.id
  end

  def participant?
    record.conversation_participants.exists?(user_id: user.id)
  end
end

ConversationPolicy.prepend_mod_with('ConversationPolicy')
