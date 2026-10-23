class Whatsapp::FacebookApiClient # rubocop:disable Metrics/ClassLength
  BASE_URI = 'https://graph.facebook.com'.freeze
  # Base webhook fields resent on every subscribe so Meta won't reset to defaults. `calls` is added by callers only when voice is enabled.
  WEBHOOK_DEFAULT_FIELDS = %w[messages smb_message_echoes].freeze

  def initialize(access_token = nil)
    @access_token = access_token
    @api_version = GlobalConfigService.load('WHATSAPP_API_VERSION', 'v22.0')
  end

  def exchange_code_for_token(code)
    response = HTTParty.get(
      "#{BASE_URI}/#{@api_version}/oauth/access_token",
      query: {
        client_id: GlobalConfigService.load('WHATSAPP_APP_ID', ''),
        client_secret: GlobalConfigService.load('WHATSAPP_APP_SECRET', ''),
        code: code
      }
    )

    handle_response(response, 'Token exchange failed')
  end

  def fetch_phone_numbers(waba_id)
    response = HTTParty.get(
      "#{BASE_URI}/#{@api_version}/#{waba_id}/phone_numbers",
      query: { access_token: @access_token }
    )

    handle_response(response, 'WABA phone numbers fetch failed')
  end

  def fetch_all_phone_numbers(waba_id)
    phone_numbers = []
    after_cursor = nil

    loop do
      response = HTTParty.get(
        "#{BASE_URI}/#{@api_version}/#{waba_id}/phone_numbers",
        headers: request_headers,
        query: after_cursor.present? ? { after: after_cursor } : {}
      )
      data = handle_response(response, 'WABA phone numbers fetch failed')
      phone_numbers.concat(data['data'] || [])
      after_cursor = data.dig('paging', 'next').present? ? data.dig('paging', 'cursors', 'after') : nil
      break if after_cursor.blank?
    end

    phone_numbers
  end

  def fetch_message_templates(waba_id)
    response = HTTParty.get(
      "#{BASE_URI}/#{@api_version}/#{waba_id}/message_templates",
      headers: request_headers,
      query: { limit: 1 }
    )

    handle_response(response, 'WABA message templates fetch failed')
  end

  def fetch_business_profile(phone_number_id)
    response = HTTParty.get(
      "#{BASE_URI}/#{@api_version}/#{phone_number_id}/whatsapp_business_profile",
      headers: request_headers,
      query: { fields: 'about' }
    )

    handle_response(response, 'WhatsApp business profile fetch failed')
  end

  def fetch_permissions
    response = HTTParty.get(
      "#{BASE_URI}/#{@api_version}/me/permissions",
      headers: request_headers
    )

    handle_response(response, 'Token permissions fetch failed')
  end

  def fetch_subscribed_apps(waba_id)
    response = HTTParty.get(
      "#{BASE_URI}/#{@api_version}/#{waba_id}/subscribed_apps",
      headers: request_headers
    )

    handle_response(response, 'WABA webhook subscription fetch failed')
  end

  def fetch_phone_number(phone_number_id, fields: nil)
    response = HTTParty.get(
      "#{BASE_URI}/#{@api_version}/#{phone_number_id}",
      headers: request_headers,
      query: fields.present? ? { fields: fields } : {}
    )

    handle_response(response, 'Phone number fetch failed')
  end

  def debug_token(input_token)
    response = HTTParty.get(
      "#{BASE_URI}/#{@api_version}/debug_token",
      query: {
        input_token: input_token,
        access_token: build_app_access_token
      }
    )

    handle_response(response, 'Token validation failed')
  end

  def register_phone_number(phone_number_id, pin)
    response = HTTParty.post(
      "#{BASE_URI}/#{@api_version}/#{phone_number_id}/register",
      headers: request_headers,
      body: { messaging_product: 'whatsapp', pin: pin.to_s }.to_json
    )

    handle_response(response, 'Phone registration failed')
  end

  # Releases the number from this app so it can be re-added under another app/BSP. Without this,
  # after an inbox is deleted the number stays registered and Meta reports "already in a partner app".
  def deregister_phone_number(phone_number_id)
    response = HTTParty.post(
      "#{BASE_URI}/#{@api_version}/#{phone_number_id}/deregister",
      headers: request_headers
    )

    handle_response(response, 'Phone deregistration failed')
  end

  def phone_number_verified?(phone_number_id)
    response = HTTParty.get(
      "#{BASE_URI}/#{@api_version}/#{phone_number_id}",
      headers: request_headers,
      query: { fields: 'status,code_verification_status' }
    )

    data = handle_response(response, 'Phone status check failed')
    data['status'] == 'CONNECTED' || data['code_verification_status'] == 'VERIFIED'
  end

  def subscribe_phone_number_webhook(waba_id, phone_number_id, callback_url, verify_token, subscribed_fields: nil)
    fields = subscribed_fields || WEBHOOK_DEFAULT_FIELDS
    # Meta requires the app to be subscribed to the WABA before any callback override (issue #13097). But posting to
    # subscribed_apps rewrites the WABA-level subscription of the app (and may drop its WABA callback override), which
    # is shared by every other number of the WABA. So it is only done when the app is not subscribed yet, or when
    # `calls` has to be added to the fields; otherwise registering one number only touches that number.
    subscribe_app_to_waba(waba_id, subscribed_fields: fields) if waba_subscription_needed?(waba_id, fields)

    # Phone-level override takes precedence over WABA-level, so numbers on one WABA can route to different URLs.
    override_phone_number_callback(phone_number_id, callback_url, verify_token)
  end

  # True when our app already appears among the apps subscribed to the WABA. Any failure to read the list counts as
  # "not subscribed" so the registration behaves exactly like before.
  def app_subscribed_to_waba?(waba_id)
    apps = Array(fetch_subscribed_apps(waba_id)['data'])
    app_id = GlobalConfigService.load('WHATSAPP_APP_ID', '').to_s
    return apps.any? if app_id.blank?

    apps.any? { |app| app.dig('whatsapp_business_api_data', 'id').to_s == app_id }
  rescue StandardError => e
    Rails.logger.warn("[WHATSAPP] Could not read the WABA subscriptions of #{waba_id}: #{e.message}")
    false
  end

  def subscribe_app_to_waba(waba_id, subscribed_fields: WEBHOOK_DEFAULT_FIELDS)
    response = HTTParty.post(
      "#{BASE_URI}/#{@api_version}/#{waba_id}/subscribed_apps",
      headers: request_headers,
      body: { subscribed_fields: subscribed_fields }.to_json
    )

    handle_response(response, 'App subscription to WABA failed')
  end

  def override_phone_number_callback(phone_number_id, callback_url, verify_token)
    response = HTTParty.post(
      "#{BASE_URI}/#{@api_version}/#{phone_number_id}",
      headers: request_headers,
      body: {
        webhook_configuration: {
          override_callback_uri: callback_url,
          verify_token: verify_token
        }
      }.to_json
    )

    handle_response(response, 'Phone number webhook callback override failed')
  end

  def clear_phone_number_callback_override(phone_number_id)
    response = HTTParty.post(
      "#{BASE_URI}/#{@api_version}/#{phone_number_id}",
      headers: request_headers,
      body: {
        webhook_configuration: {
          override_callback_uri: ''
        }
      }.to_json
    )

    handle_response(response, 'Phone number webhook callback clear failed')
  end

  # Fully removes this app's WABA subscription (last inbox deleted) so Meta stops delivering webhooks.
  def unsubscribe_app_from_waba(waba_id)
    response = HTTParty.delete(
      "#{BASE_URI}/#{@api_version}/#{waba_id}/subscribed_apps",
      headers: request_headers
    )

    handle_response(response, 'WABA app unsubscription failed')
  end

  private

  # Fields beyond the default ones (`calls`) can only be requested by posting to subscribed_apps.
  def waba_subscription_needed?(waba_id, fields)
    return true unless (fields - WEBHOOK_DEFAULT_FIELDS).empty?

    !app_subscribed_to_waba?(waba_id)
  end

  def request_headers
    {
      'Authorization' => "Bearer #{@access_token}",
      'Content-Type' => 'application/json'
    }
  end

  def build_app_access_token
    app_id = GlobalConfigService.load('WHATSAPP_APP_ID', '')
    app_secret = GlobalConfigService.load('WHATSAPP_APP_SECRET', '')
    "#{app_id}|#{app_secret}"
  end

  def handle_response(response, error_message)
    raise "#{error_message}: #{response.body}" unless response.success?

    response.parsed_response
  end
end
