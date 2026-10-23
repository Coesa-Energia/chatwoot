# Meta error 138006 means the contact hasn't opted in to calls yet, so ask for permission. When the customer
# wrote in the last 24h the first ask goes as the free-form interactive message; re-asks, and customers who
# never wrote, go through the approved call-permission template.
class Whatsapp::CallPermissionRequestService
  THROTTLE = 5.minutes
  REQUESTS_KEY = 'call_permission_requests'.freeze
  REQUESTED_AT_KEY = 'call_permission_requested_at'.freeze
  MESSAGE_ID_KEY = 'call_permission_request_message_id'.freeze

  pattr_initialize [:conversation!, :recipient!]

  # Plain-language reason from the last failed attempt (nil when it was a transport error).
  attr_reader :error_message

  # Locked so two agents calling the same contact can't both send the template.
  def perform
    conversation.with_lock do
      next 'permission_pending' if throttled?

      sent = send_request_safely
      next 'failed' if sent.blank?

      record_wamid(sent)
      emit_activity
      'permission_requested'
    end
  end

  private

  def throttled?
    last_requested = permission_request_attrs[REQUESTED_AT_KEY]
    last_requested.present? && Time.zone.parse(last_requested) > THROTTLE.ago
  end

  # Treat transport errors as a falsy return so the caller renders 422 rather than 500.
  def send_request_safely
    kinds = attempts
    @error_message = I18n.t('errors.whatsapp.calls.meta.outside_window') if kinds.empty?
    kinds.each do |kind|
      sent = deliver(kind)
      return sent if sent.present?
      break if request_blocked?
    end
    nil
  end

  # The free-form message only reaches a customer who wrote in the last 24h; otherwise only the approved
  # template can. A customer who never wrote therefore always gets the template.
  def attempts
    interactive = customer_wrote_recently?
    order = previously_requested? || !interactive ? %i[template interactive] : %i[interactive template]
    order.select { |kind| kind == :template ? template_service.approved? : interactive }
  end

  def deliver(kind)
    @error_message = nil
    @last_code = nil
    if kind == :template
      provider_service.send_call_permission_template(recipient, template_service.name, template_service.language)
    else
      provider_service.send_call_permission_request(recipient, *body_args)
    end
  rescue StandardError => e
    Rails.logger.warn "[WHATSAPP CALL] permission_request (#{kind}) failed: #{e.class} #{e.message}"
    capture_error(e)
    nil
  end

  def capture_error(error)
    return unless error.is_a?(Voice::CallErrors::PermissionRequestFailed)

    @last_code = error.code
    @error_message = error.message
  end

  # Limits Meta reports per business/contact pair: asking again through another channel can't help.
  def request_blocked?
    Voice::CallErrors::PERMISSION_REQUEST_BLOCKED_CODES.include?(@last_code)
  end

  # The window belongs to the WhatsApp user, not to one thread: a contact reachable under a phone number and a
  # BSUID may have written in a different conversation of this inbox.
  def customer_wrote_recently?
    thread_ids = conversation.inbox.conversations.where(contact_id: conversation.contact_id).select(:id)
    # A call bubble is not the customer writing, so it doesn't open the window
    Message.incoming.where.not(content_type: :voice_call).where(conversation_id: thread_ids)
           .exists?(['created_at > ?', Conversations::MessageWindowService::MESSAGING_WINDOW_24_HOURS.ago])
  end

  def previously_requested?
    permission_request_attrs[REQUESTED_AT_KEY].present?
  end

  def template_service
    @template_service ||= Whatsapp::CallPermissionTemplateService.new(channel: conversation.inbox.channel)
  end

  # Pass the inbox-level override only when present so the provider falls back
  # to the i18n default for inboxes that haven't customized the prompt.
  def body_args
    custom_body = conversation.inbox.channel.provider_config&.dig('call_permission_request_body').presence
    custom_body ? [custom_body] : []
  end

  def emit_activity
    content = I18n.t('conversations.activity.whatsapp_call.permission_requested', contact_name: conversation.contact.name)
    ::Conversations::ActivityMessageJob.perform_later(
      conversation,
      { account_id: conversation.account_id, inbox_id: conversation.inbox_id, message_type: :activity, content: content }
    )
  end

  # Stash the outbound wamid so the reply webhook can match context.id back here.
  def record_wamid(sent)
    requested_at = Time.current.iso8601
    request_attrs = {
      REQUESTED_AT_KEY => requested_at,
      MESSAGE_ID_KEY => sent.dig('messages', 0, 'id')
    }
    attrs = (conversation.additional_attributes || {}).merge(
      REQUESTED_AT_KEY => requested_at,
      MESSAGE_ID_KEY => request_attrs[MESSAGE_ID_KEY],
      REQUESTS_KEY => permission_requests.merge(recipient_key => request_attrs)
    )
    conversation.update!(additional_attributes: attrs)
  end

  def provider_service
    @provider_service ||= conversation.inbox.channel.provider_service
  end

  def permission_request_attrs
    permission_requests.fetch(recipient_key, {})
  end

  def permission_requests
    attrs = conversation.additional_attributes || {}
    requests = attrs.fetch(REQUESTS_KEY, {})
    return requests if requests.present?

    # Legacy requests always targeted the contact phone. Preserve their throttle and
    # reply WAMID under that identity before another recipient replaces the top-level fields.
    legacy_request = attrs.slice(REQUESTED_AT_KEY, MESSAGE_ID_KEY).compact
    phone_recipient = conversation.contact.phone_number&.delete('+')
    return requests if legacy_request.blank? || phone_recipient.blank?

    { phone_recipient => legacy_request }
  end

  def recipient_key
    recipient.to_s
  end
end
