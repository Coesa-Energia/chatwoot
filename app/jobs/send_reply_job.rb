class SendReplyJob < ApplicationJob
  queue_as :high

  CHANNEL_SERVICES = {
    'Channel::TwitterProfile' => ::Twitter::SendOnTwitterService,
    'Channel::TwilioSms' => ::Twilio::SendOnTwilioService,
    'Channel::Line' => ::Line::SendOnLineService,
    'Channel::Telegram' => ::Telegram::SendOnTelegramService,
    'Channel::Whatsapp' => ::Whatsapp::SendOnWhatsappService,
    'Channel::Sms' => ::Sms::SendOnSmsService,
    'Channel::Instagram' => ::Instagram::SendOnInstagramService,
    'Channel::Tiktok' => ::Tiktok::SendOnTiktokService,
    'Channel::Email' => ::Email::SendOnEmailService,
    'Channel::WebWidget' => ::Messages::SendEmailNotificationService,
    'Channel::Api' => ::Messages::SendEmailNotificationService
  }.freeze

  # WhatsApp rate limits and connection failures (the request never reached Meta) are safe to
  # retry. Back off 10s, 20s, 30s, 40s; when attempts run out, mark the message as failed so
  # the agent sees it and can resend.
  retry_on CustomExceptions::WhatsappRetryableError, wait: ->(executions) { executions * 10.seconds }, attempts: 5 do |job, error|
    Message.find_by(id: job.arguments.first)&.update!(status: :failed, external_error: error.message)
  end

  def perform(message_id)
    message = Message.find(message_id)
    channel_name = message.conversation.inbox.channel.class.to_s

    Captain::Conversation::AgentMessageTranslationService.new(message: message).perform if message.content_attributes['translation_pending']

    return send_on_facebook_page(message) if channel_name == 'Channel::FacebookPage'

    service_class = CHANNEL_SERVICES[channel_name]
    return unless service_class

    service_class.new(message: message).perform
  end

  private

  def send_on_facebook_page(message)
    if message.conversation.additional_attributes['type'] == 'instagram_direct_message'
      ::Instagram::Messenger::SendOnInstagramService.new(message: message).perform
    else
      ::Facebook::SendOnFacebookService.new(message: message).perform
    end
  end
end
