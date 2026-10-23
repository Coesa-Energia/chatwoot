# Inbound WhatsApp reactions arrive as a message of type `reaction`:
#   { from:, id:, type: 'reaction', reaction: { message_id: <wamid of the reacted message>, emoji: '👍' } }
# An empty or missing emoji means the reaction was removed. They never create a message or a
# conversation; they annotate the reacted message (see Whatsapp::MessageReactions).
module Whatsapp::IncomingReactionHandler
  private

  def process_reaction
    reaction = messages_data.first[:reaction]
    return if reaction.blank?

    target = inbox.messages.find_by(source_id: reaction[:message_id])
    return if target.blank?

    # An echo is a message the business sent from the WhatsApp Business app, so it is the business side reacting.
    Whatsapp::MessageReactions.new(message: target).set(outgoing_echo ? 'business' : 'contact', reaction[:emoji])
  end
end
