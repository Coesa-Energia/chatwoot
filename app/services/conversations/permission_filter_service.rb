class Conversations::PermissionFilterService
  attr_reader :conversations, :user, :account

  def initialize(conversations, user, account, plan_hint_selective_filter: false)
    @conversations = conversations
    @user = user
    @account = account
    @plan_hint_selective_filter = plan_hint_selective_filter
  end

  def perform
    return agent_bot_conversations if user.is_a?(AgentBot)
    return conversations if user_role == 'administrator'

    accessible_conversations
  end

  private

  def accessible_conversations
    in_member_inboxes = if @plan_hint_selective_filter
                          hinted_accessible_conversations
                        else
                          conversations.where(inbox: user.inboxes.where(account_id: account.id))
                        end
    Inboxes::ConversationAccess.apply(in_member_inboxes, user: user, account: account)
  end

  # Same rows as accessible_conversations. `inbox_id + 0` keeps the planner from
  # driving the query through an inbox scan, which it grossly misestimates when a
  # highly selective filter (e.g. labels) is present on large accounts (CW-7787).
  def hinted_accessible_conversations
    conversations.where(
      '(conversations.inbox_id + 0) IN (
        SELECT inbox_members.inbox_id FROM inbox_members
        INNER JOIN inboxes ON inboxes.id = inbox_members.inbox_id
        WHERE inbox_members.user_id = :user_id AND inboxes.account_id = :account_id
      )',
      user_id: user.id, account_id: account.id
    )
  end

  # Bots (automation profiles) see their own account, as ConversationPolicy#show? already lets them; never another one.
  def agent_bot_conversations
    user.account_id == account.id ? conversations : conversations.none
  end

  # A bot id can collide with a user id: never read that user's role for a bot.
  def account_user
    return unless user.is_a?(User)

    AccountUser.find_by(account_id: account.id, user_id: user.id)
  end

  def user_role
    account_user&.role
  end
end

Conversations::PermissionFilterService.prepend_mod_with('Conversations::PermissionFilterService')
