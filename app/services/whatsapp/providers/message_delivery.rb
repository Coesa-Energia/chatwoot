# Posting a message to the WhatsApp Cloud API, with the failure handling the job layer relies on.
# Expects the including provider to implement `api_headers` and `process_response(response, message)`.
module Whatsapp::Providers::MessageDelivery
  # Errors where the request never reached Meta, so sending again cannot duplicate the message.
  CONNECTION_ERRORS = [Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError, Net::OpenTimeout].freeze
  # Errors after the request was (possibly) accepted: we cannot know if it was delivered.
  UNCONFIRMED_ERRORS = [Net::ReadTimeout, Net::WriteTimeout, Timeout::Error].freeze

  # Reacts to a message with an emoji (an empty emoji removes the reaction).
  # Returns [whatsapp_message_id, nil] on success or [nil, error_message] on failure.
  def send_reaction(phone_number, target_source_id, emoji)
    request_body = {
      messaging_product: 'whatsapp',
      recipient_type: 'individual',
      **recipient_params(phone_number),
      type: 'reaction',
      reaction: { message_id: target_source_id, emoji: emoji }
    }
    response = HTTParty.post("#{phone_id_path}/messages", headers: api_headers, body: request_body.to_json, open_timeout: 10, read_timeout: 30)
    return [response.parsed_response.dig('messages', 0, 'id'), nil] if response.success?

    [nil, error_message(response).presence || I18n.t('errors.whatsapp.reaction_failed')]
  rescue *CONNECTION_ERRORS, *UNCONFIRMED_ERRORS => e
    Rails.logger.warn("[WHATSAPP] reaction not sent (#{e.class})")
    [nil, I18n.t('errors.whatsapp.reaction_failed')]
  end

  # Tells WhatsApp the customer's message was read, so the customer sees the blue ticks.
  # Returns true on success.
  def mark_as_read(source_id)
    response = HTTParty.post("#{phone_id_path}/messages", headers: api_headers,
                                                          body: { messaging_product: 'whatsapp', status: 'read', message_id: source_id }.to_json,
                                                          open_timeout: 10, read_timeout: 30)
    Rails.logger.warn("[WHATSAPP] read receipt not accepted for #{source_id}: #{response.code} #{response.body}") unless response.success?
    response.success?
  rescue *CONNECTION_ERRORS, *UNCONFIRMED_ERRORS => e
    Rails.logger.warn("[WHATSAPP] read receipt not sent (#{e.class})")
    false
  end

  private

  # Posts a message and returns its WhatsApp id, or nil when it failed (the failure is
  # recorded on the message). Raises CustomExceptions::WhatsappRetryableError when the
  # request was rate limited or never reached Meta; SendReplyJob retries those with backoff.
  # With retryable: false the retryable errors are recorded as a failure instead of raised.
  def deliver_message(url, request_body, message, retryable: true)
    post_and_process(url, request_body, message)
  rescue CustomExceptions::WhatsappRetryableError => e
    raise if retryable

    record_send_failure(message, e.message)
  end

  def post_and_process(url, request_body, message)
    response = HTTParty.post(url, headers: api_headers, body: request_body.to_json, open_timeout: 10, read_timeout: 30)
    process_response(response, message)
  rescue *CONNECTION_ERRORS => e
    Rails.logger.warn("[WHATSAPP] could not reach Meta (#{e.class}) for message #{message&.id}")
    raise CustomExceptions::WhatsappRetryableError, { reason: 'connection' }
  rescue *UNCONFIRMED_ERRORS => e
    Rails.logger.warn("[WHATSAPP] timeout waiting for Meta (#{e.class}) for message #{message&.id}; delivery unconfirmed")
    record_send_failure(message, I18n.t('errors.whatsapp.send_unconfirmed'))
  end

  def record_send_failure(message, error_message)
    message.update!(status: :failed, external_error: error_message)
    nil
  end
end
