# WhatsApp removes a contact's call permission after 4 consecutive unanswered business-initiated calls.
# This drops a note in the conversation after every unanswered outgoing call so agents see how close the
# contact is to losing it. The count restarts when the contact grants permission again (see
# CallPermissionReplyService) and is broken by any answered call.
class Whatsapp::UnansweredCallNotifier
  MAX_UNANSWERED = 4
  GRANTED_AT_KEY = 'call_permission_granted_at'.freeze

  pattr_initialize [:call!]

  def perform
    return unless call.whatsapp? && call.outgoing? && call.status == 'no_answer'

    count = consecutive_unanswered
    return if count.zero?

    post_activity(count)
  rescue StandardError => e
    # A note must never get in the way of finishing the call.
    Rails.logger.warn "[WHATSAPP CALL] unanswered notice failed: #{e.class} #{e.message}"
  end

  private

  def consecutive_unanswered
    count = 0
    recent_outgoing_calls.each do |previous|
      break unless previous.status == 'no_answer'

      count += 1
    end
    count
  end

  # Newest first; calls still ringing are ignored because they have no outcome yet.
  def recent_outgoing_calls
    scope = Call.whatsapp.outgoing.where(contact_id: call.contact_id, inbox_id: call.inbox_id, status: Call::TERMINAL_STATUSES)
    granted_at = Time.zone.parse(call.conversation.additional_attributes&.dig(GRANTED_AT_KEY).to_s)
    scope = scope.where('created_at >= ?', granted_at) if granted_at
    scope.order(created_at: :desc).limit(MAX_UNANSWERED)
  end

  def post_activity(count)
    key = count >= MAX_UNANSWERED ? 'permission_revoked' : 'unanswered_call'
    content = I18n.t("conversations.activity.whatsapp_call.#{key}", contact_name: call.contact&.name, count: count, max: MAX_UNANSWERED)
    ::Conversations::ActivityMessageJob.perform_later(
      call.conversation,
      { account_id: call.account_id, inbox_id: call.inbox_id, message_type: :activity, content: content }
    )
  end
end
