# Sends the WhatsApp "read" receipt (blue ticks) for the latest customer message once an agent has
# seen the conversation. Meta marks every earlier message as read too, so only the newest incoming
# message needs it. A channel can opt out with provider_config['send_read_receipts'] = false.
class Whatsapp::ReadReceiptService
  # WhatsApp only accepts read receipts for recent messages.
  MAX_MESSAGE_AGE = 30.days
  TRACKING_KEY = 'whatsapp_read_receipt_message_id'.freeze

  pattr_initialize [:conversation!]

  def perform
    return unless eligible_channel?

    message = latest_incoming_message
    return if message.blank? || already_sent?(message) || !seen_by_agent?(message)
    return unless channel.provider_service.mark_as_read(message.source_id)

    remember(message)
  end

  private

  def channel
    @channel ||= conversation.inbox.channel
  end

  def eligible_channel?
    channel.is_a?(Channel::Whatsapp) && channel.provider == 'whatsapp_cloud' &&
      channel.provider_config['send_read_receipts'] != false
  end

  def latest_incoming_message
    conversation.messages.incoming.where('source_id LIKE ?', 'wamid.%')
                .where('messages.created_at > ?', MAX_MESSAGE_AGE.ago)
                .reorder(created_at: :desc, id: :desc).first
  end

  def seen_by_agent?(message)
    conversation.agent_last_seen_at.present? && conversation.agent_last_seen_at >= message.created_at
  end

  def already_sent?(message)
    conversation.additional_attributes[TRACKING_KEY].to_i >= message.id
  end

  def remember(message)
    # rubocop:disable Rails/SkipsModelValidations
    conversation.update_columns(additional_attributes: conversation.additional_attributes.merge(TRACKING_KEY => message.id))
    # rubocop:enable Rails/SkipsModelValidations
  end
end
