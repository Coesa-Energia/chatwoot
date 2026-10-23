class Whatsapp::ManualWebhookStatusService
  WEBHOOK_PATH = '/webhooks/whatsapp'.freeze
  # Meta resolves the callback by priority: phone number override, then WABA, then app.
  CALLBACK_KEYS = %w[override_callback_uri phone_number whatsapp_business_account application].freeze

  def initialize(channel)
    @channel = channel
    @api_client = Whatsapp::FacebookApiClient.new(channel.provider_config['api_key'])
  end

  def perform
    callback_configured = callback_configured?

    {
      callback_verified: callback_configured,
      callback_configured: callback_configured,
      callback_url: callback_url,
      subscription_verified: subscription_verified?
    }
  end

  private

  def callback_configured?
    phone_number = @api_client.fetch_phone_number(
      @channel.provider_config['phone_number_id'],
      fields: 'webhook_configuration'
    )
    webhook_configuration = phone_number.fetch('webhook_configuration', {})

    valid_callback?(webhook_configuration.values_at(*CALLBACK_KEYS).compact_blank.first)
  end

  # Several numbers of one WABA can share a single callback URL. The inbox is resolved from the
  # payload, so the trailing phone number in the path does not matter: only another host or a
  # path outside our WhatsApp endpoint means the callback is wrong.
  def valid_callback?(configured_url)
    return false if configured_url.blank?
    return true if configured_url == callback_url

    configured = URI.parse(configured_url)
    expected = URI.parse(callback_url)
    same_origin?(configured, expected) && whatsapp_webhook_path?(configured.path)
  rescue URI::InvalidURIError
    false
  end

  def same_origin?(configured, expected)
    [configured.scheme, configured.host&.downcase, configured.port] == [expected.scheme, expected.host&.downcase, expected.port]
  end

  def whatsapp_webhook_path?(path)
    path == WEBHOOK_PATH || path.to_s.start_with?("#{WEBHOOK_PATH}/")
  end

  def subscription_verified?
    @api_client.fetch_subscribed_apps(@channel.provider_config['business_account_id']).fetch('data', []).present?
  end

  def callback_url
    "#{ENV.fetch('FRONTEND_URL', nil)}/webhooks/whatsapp/#{@channel.phone_number}"
  end
end
