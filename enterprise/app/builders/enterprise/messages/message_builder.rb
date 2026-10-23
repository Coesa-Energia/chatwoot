module Enterprise::Messages::MessageBuilder
  private

  def message_type
    return @message_type if @message_type == 'incoming' && voice_call_inbox? && @params[:content_type] == 'voice_call'

    super
  end

  # WhatsApp too: a phone (Twilio) call is logged in the contact's WhatsApp thread even when WhatsApp calling is off
  def voice_call_inbox?
    @conversation.inbox.whatsapp? || @conversation.inbox.channel.try(:voice_enabled?)
  end
end
