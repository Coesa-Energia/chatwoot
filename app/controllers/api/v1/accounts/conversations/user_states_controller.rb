# Pin / archive a conversation for the current agent only (like the WhatsApp app's pinned and archived chats).
class Api::V1::Accounts::Conversations::UserStatesController < Api::V1::Accounts::Conversations::BaseController
  skip_before_action :conversation, only: :archived_ids

  def update
    state = ConversationUserState.find_or_initialize_by(user_id: Current.user.id, conversation_id: @conversation.id)
    state.account_id = @conversation.account_id
    apply_changes(state)

    if state.pinned_at.nil? && state.archived_at.nil?
      state.destroy if state.persisted?
    elsif !state.save
      return render json: { error: state.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end

    render json: { id: @conversation.display_id, pinned_at: state.pinned_at&.to_i, archived_at: state.archived_at&.to_i }
  end

  # Ids (display ids) of the conversations the agent archived. The dashboard uses them to keep archived
  # conversations out of the main list even when a websocket event for one of them arrives.
  def archived_ids
    ids = ConversationUserState.where(account_id: Current.account.id, user_id: Current.user.id)
                               .where.not(archived_at: nil)
                               .joins(:conversation).pluck('conversations.display_id')
    render json: { payload: ids }
  end

  private

  def apply_changes(state)
    state.pinned_at = enabled?(:pinned) ? (state.pinned_at || Time.current) : nil if params.key?(:pinned)
    state.archived_at = enabled?(:archived) ? Time.current : nil if params.key?(:archived)
  end

  def enabled?(key)
    ActiveModel::Type::Boolean.new.cast(params[key])
  end
end
