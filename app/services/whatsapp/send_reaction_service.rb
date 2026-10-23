# An agent reacts to a WhatsApp message with an emoji (an empty emoji removes the reaction).
# Returns nil on success, or an error message to show the agent.
class Whatsapp::SendReactionService
  MAX_EMOJI_LENGTH = 16

  pattr_initialize [:message!, :emoji!]

  def perform
    return I18n.t('errors.whatsapp.reaction_invalid') if emoji.length > MAX_EMOJI_LENGTH
    return I18n.t('errors.whatsapp.reactions_unsupported') unless reactable?
    return I18n.t('errors.whatsapp.message_outside_messaging_window') unless conversation.can_reply?

    _id, error = channel.provider_service.send_reaction(conversation.contact_inbox.source_id, message.source_id, emoji)
    return error if error.present?

    Whatsapp::MessageReactions.new(message: message).set('business', emoji)
    nil
  end

  private

  delegate :conversation, to: :message

  def channel
    conversation.inbox.channel
  end

  # Only WhatsApp Cloud supports reactions, and only on real customer-facing messages that have a WhatsApp id.
  def reactable?
    channel.is_a?(Channel::Whatsapp) && channel.provider == 'whatsapp_cloud' &&
      !message.private? && !message.activity? && message.source_id.to_s.start_with?('wamid.')
  end
end
