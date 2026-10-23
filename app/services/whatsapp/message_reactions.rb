# Emoji reactions on a WhatsApp message, stored on the reacted message as
#   content_attributes['reactions'] = { 'contact' => '👍', 'business' => '❤️' }
# A WhatsApp chat is 1:1, so there is at most one reaction per side: the customer ('contact') and
# the business ('business', whichever agent reacted). An empty emoji removes the reaction.
class Whatsapp::MessageReactions
  SIDES = %w[contact business].freeze

  pattr_initialize [:message!]

  def set(side, emoji)
    raise ArgumentError, "unknown side #{side}" unless SIDES.include?(side)

    reactions = (message.content_attributes['reactions'] || {}).to_h.dup
    emoji.present? ? reactions[side] = emoji : reactions.delete(side)
    save(reactions)
  end

  private

  def save(reactions)
    attributes = message.content_attributes.deep_dup
    reactions.empty? ? attributes.delete('reactions') : attributes['reactions'] = reactions
    message.update!(content_attributes: attributes)
  end
end
