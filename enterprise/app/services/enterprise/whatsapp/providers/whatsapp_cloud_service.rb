module Enterprise::Whatsapp::Providers::WhatsappCloudService # rubocop:disable Metrics/ModuleLength
  # Calls API + the call_permission_request interactive message both require Graph
  # API v17+; OSS phone_id_path is locked at v13.0 for legacy /messages compatibility.
  # Use the configured global version (defaulting to v22.0) for call-flow endpoints.
  WHATSAPP_CALLING_API_VERSION_FALLBACK = 'v22.0'.freeze

  def pre_accept_call(call_id, sdp_answer)
    call_api('pre_accept_call', call_action_body(call_id, 'pre_accept', sdp_answer))
  end

  def accept_call(call_id, sdp_answer)
    call_api('accept_call', call_action_body(call_id, 'accept', sdp_answer))
  end

  def reject_call(call_id)
    call_api('reject_call', call_action_body(call_id, 'reject'))
  end

  def terminate_call(call_id)
    call_api('terminate_call', call_action_body(call_id, 'terminate'))
  end

  # Free-form permission request; Meta only delivers it inside the 24h customer-service window.
  # Raises Voice::CallErrors::PermissionRequestFailed (readable message + Meta code) on failure.
  def send_call_permission_request(recipient, body_text = I18n.t('conversations.messages.whatsapp.call_permission_request_body'))
    post_permission_message(permission_request_body(recipient, body_text), 'send_call_permission_request')
  end

  # Template-based permission request (call_permission_request component). Works outside the 24h window.
  def send_call_permission_template(recipient, name, language)
    post_permission_message(permission_template_body(recipient, name, language), 'send_call_permission_template')
  end

  # Registers the call-permission template on the WABA; Meta reviews it, so it starts out PENDING.
  # Returns the parsed response, or raises Voice::CallErrors::CallFailed.
  def create_call_permission_template(name:, language:, body:, category: 'UTILITY')
    payload = call_permission_template_payload(name, language, body, category)
    response = HTTParty.post("#{calls_business_account_path}/message_templates", headers: api_headers, body: payload.to_json)
    return response.parsed_response if response.success?

    Rails.logger.error "[WHATSAPP CALL] create_call_permission_template failed: status=#{response.code} body=#{response.body}"
    error = parsed_meta_error(response)
    raise Voice::CallErrors::CallFailed.new(meta_error_message(error, 'Failed to create template'), code: error['code'])
  end

  # The WABA's template with this name as Meta has it (status, body, rejection reason), or nil when it does
  # not exist. Raises Voice::CallErrors::CallFailed when Meta cannot be reached.
  def find_message_template(name)
    response = HTTParty.get("#{calls_business_account_path}/message_templates", headers: api_headers, query: {
                              name: name, fields: 'id,name,status,language,category,components,rejected_reason'
                            })
    unless response.success?
      Rails.logger.error "[WHATSAPP CALL] find_message_template failed: status=#{response.code} body=#{response.body}"
      raise Voice::CallErrors::CallFailed.new(meta_error_message(parsed_meta_error(response), 'Failed to read template'),
                                              code: parsed_meta_error(response)['code'])
    end

    Array(response.parsed_response['data']).find { |template| template['name'] == name }
  end

  # What the contact allowed this number to do, plus Meta's request/call limits
  # (GET /{phone}/call_permissions). Raises Voice::CallErrors::CallFailed on failure.
  def fetch_call_permissions(recipient)
    response = HTTParty.get("#{calls_phone_id_path}/call_permissions", headers: api_headers, query: call_permission_query(recipient))
    return response.parsed_response if response.success?

    Rails.logger.error "[WHATSAPP CALL] fetch_call_permissions failed: status=#{response.code} body=#{response.body}"
    code = parsed_meta_error(response)['code']
    raise Voice::CallErrors::CallFailed.new(Voice::CallErrors.friendly_message(code), code: code)
  end

  def initiate_call(recipient, sdp_offer)
    response = HTTParty.post(
      "#{calls_phone_id_path}/calls", headers: api_headers, body: initiate_call_body(recipient, sdp_offer)
    )
    process_initiate_call_response(response)
  end

  # Sets WABA calling status ('ENABLED'/'DISABLED'). Returns true, or raises with
  # Meta's user-facing message on failure so the caller can surface it.
  def update_calling_status(status)
    response = HTTParty.post(
      "#{calls_phone_id_path}/settings",
      headers: api_headers,
      body: { calling: { status: status } }.to_json
    )
    return true if response.success?

    parsed = response.parsed_response.is_a?(Hash) ? response.parsed_response : {}
    error = parsed['error'].is_a?(Hash) ? parsed['error'] : {}
    Rails.logger.error "[WHATSAPP CALL] update_calling_status failed: status=#{response.code} body=#{response.body}"
    raise meta_error_message(error, 'Failed to update calling status')
  end

  private

  def calls_phone_id_path
    base = ENV.fetch('WHATSAPP_CLOUD_BASE_URL', 'https://graph.facebook.com')
    version = GlobalConfigService.load('WHATSAPP_API_VERSION', WHATSAPP_CALLING_API_VERSION_FALLBACK)
    "#{base}/#{version}/#{whatsapp_channel.provider_config['phone_number_id']}"
  end

  def calls_business_account_path
    base = ENV.fetch('WHATSAPP_CLOUD_BASE_URL', 'https://graph.facebook.com')
    version = GlobalConfigService.load('WHATSAPP_API_VERSION', WHATSAPP_CALLING_API_VERSION_FALLBACK)
    "#{base}/#{version}/#{whatsapp_channel.provider_config['business_account_id']}"
  end

  def call_action_body(call_id, action, sdp_answer = nil)
    body = { messaging_product: 'whatsapp', call_id: call_id, action: action }
    body[:session] = { sdp: sdp_answer, sdp_type: 'answer' } if sdp_answer
    body
  end

  def call_api(action_name, body)
    url = "#{calls_phone_id_path}/calls"
    Rails.logger.info "[WHATSAPP CALL] #{action_name} POST #{url} body=#{body.except(:session).to_json}"
    response = HTTParty.post(url, headers: api_headers, body: body.to_json)
    Rails.logger.error "[WHATSAPP CALL] #{action_name} failed: status=#{response.code} body=#{response.body}" unless response.success?
    response.success?
  end

  def permission_request_body(recipient, body_text)
    {
      messaging_product: 'whatsapp', recipient_type: 'individual', **recipient_params(recipient),
      type: 'interactive',
      interactive: {
        type: 'call_permission_request',
        action: { name: 'call_permission_request' },
        body: { text: body_text }
      }
    }.to_json
  end

  def permission_template_body(recipient, name, language)
    {
      messaging_product: 'whatsapp', recipient_type: 'individual', **recipient_params(recipient),
      type: 'template', template: { name: name, language: { code: language } }
    }.to_json
  end

  def call_permission_template_payload(name, language, body, category)
    {
      name: name, language: language, category: category, allow_category_change: true,
      components: [{ type: 'BODY', text: body }, { type: 'call_permission_request' }]
    }
  end

  def post_permission_message(body, action_name)
    response = HTTParty.post("#{calls_phone_id_path}/messages", headers: api_headers, body: body)
    return response.parsed_response if response.success?

    Rails.logger.error "[WHATSAPP CALL] #{action_name} failed: status=#{response.code} body=#{response.body}"
    code = parsed_meta_error(response)['code']
    raise Voice::CallErrors::PermissionRequestFailed.new(Voice::CallErrors.friendly_message(code), code: code)
  end

  def call_permission_query(recipient)
    recipient.to_s.match?(RegexHelper::WHATSAPP_BSUID_REGEX) ? { recipient: recipient } : { user_wa_id: recipient }
  end

  def parsed_meta_error(response)
    parsed = response.parsed_response.is_a?(Hash) ? response.parsed_response : {}
    parsed['error'].is_a?(Hash) ? parsed['error'] : {}
  end

  def initiate_call_body(recipient, sdp_offer)
    {
      messaging_product: 'whatsapp', **call_recipient_params(recipient), action: 'connect',
      session: { sdp: sdp_offer, sdp_type: 'offer' }
    }.to_json
  end

  def call_recipient_params(recipient)
    recipient.to_s.match?(RegexHelper::WHATSAPP_BSUID_REGEX) ? { recipient: recipient } : { to: recipient }
  end

  def process_initiate_call_response(response)
    return response.parsed_response if response.success?

    Rails.logger.error "[WHATSAPP CALL] initiate_call failed: status=#{response.code} body=#{response.body}"
    error = parsed_meta_error(response)
    error_code = error['code']
    if error_code == Voice::CallErrors::NO_CALL_PERMISSION_CODE
      raise Voice::CallErrors::NoCallPermission,
            meta_error_message(error, 'Failed to initiate call')
    end

    raise Voice::CallErrors::CallFailed.new(Voice::CallErrors.friendly_message(error_code), code: error_code)
  end

  # Meta often returns a blank error_user_msg (e.g. code 131044 business-eligibility);
  # an empty string is truthy, so `||` would surface it. Prefer the first non-blank field.
  def meta_error_message(error, default)
    error['error_user_msg'].presence || error['message'].presence || error['error_user_title'].presence || default
  end
end
