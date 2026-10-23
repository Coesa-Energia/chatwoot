class Webhooks::WhatsappController < ActionController::API
  include MetaTokenVerifyConcern

  before_action :verify_meta_signature!, only: :process_payload
  before_action :verify_webhook_token!, only: :process_payload

  def process_payload
    if inactive_whatsapp_number?
      Rails.logger.warn("Rejected webhook for inactive WhatsApp number: #{params[:phone_number]}")
      render json: { error: 'Inactive WhatsApp number' }, status: :unprocessable_entity
      return
    end

    return head :ok if tracking_events_only?

    # The 360dialog secret token is only for authentication; keep it out of the job arguments.
    Whatsapp::WebhookPayloadSplitter.split(params.to_unsafe_hash.except(:token)).each do |payload|
      Webhooks::WhatsappEventsJob.perform_later(payload)
    end
    head :ok
  end

  private

  def tracking_events_only?
    return false unless params[:object] == 'whatsapp_business_account'

    changes = params.fetch(:entry, []).flat_map { |entry| entry.fetch(:changes, []) }
    changes.present? && changes.all? { |change| change[:field] == 'tracking_events' }
  end

  def valid_token?(token)
    channel = Channel::Whatsapp.find_by(phone_number: params[:phone_number])
    whatsapp_webhook_verify_token = channel.provider_config['webhook_verify_token'] if channel.present?
    token == whatsapp_webhook_verify_token if whatsapp_webhook_verify_token.present?
  end

  def meta_app_secrets
    [
      *channel_meta_app_secrets(whatsapp_channel),
      GlobalConfigService.load('WHATSAPP_APP_SECRET', nil)
    ]
  end

  def whatsapp_channel
    @whatsapp_channel ||= whatsapp_business_payload_channel || Channel::Whatsapp.find_by(phone_number: params[:phone_number])
  end

  # Webhooks are always authenticated. WhatsApp Cloud (Meta) signs them, so a valid
  # X-Hub-Signature-256 is required even for manual channels; with no app secret configured
  # (channel app_secret or the global WHATSAPP_APP_SECRET) every webhook is rejected.
  # 360dialog does not sign webhooks; see verify_webhook_token!.
  def meta_signature_verification_required?
    whatsapp_channel.blank? || whatsapp_channel.provider == 'whatsapp_cloud'
  end

  def verify_meta_signature!
    if meta_signature_verification_required? && meta_app_secrets.all?(&:blank?)
      Rails.logger.warn(
        "[WHATSAPP] Webhook rejected: no Meta app secret is configured for #{whatsapp_channel&.phone_number || params[:phone_number]}. " \
        'Set WHATSAPP_APP_SECRET (Super Admin > App Settings) or the channel app_secret.'
      )
    end
    super
  end

  # 360dialog posts to a URL that carries the channel's secret token (?token=...), generated
  # when the channel is created. A channel without a secret rejects everything.
  def verify_webhook_token!
    return unless whatsapp_channel&.provider == 'default'
    return if valid_webhook_secret?(params[:token])

    Rails.logger.warn("[WHATSAPP] 360dialog webhook rejected: missing or invalid token for #{whatsapp_channel.phone_number}")
    head :unauthorized
  end

  def valid_webhook_secret?(provided)
    expected = whatsapp_channel.provider_config['webhook_secret'].to_s
    expected.present? && ActiveSupport::SecurityUtils.secure_compare(expected, provided.to_s)
  end

  def whatsapp_business_payload_channel
    return unless params[:object] == 'whatsapp_business_account'

    metadata = params.dig(:entry, 0, :changes, 0, :value, :metadata)
    return if metadata.blank?

    Whatsapp::WebhookChannelFinderService.new(
      display_phone_number: metadata[:display_phone_number],
      phone_number_id: metadata[:phone_number_id]
    ).perform
  end

  def inactive_whatsapp_number?
    phone_number = params[:phone_number]
    return false if phone_number.blank?

    inactive_numbers = GlobalConfig.get_value('INACTIVE_WHATSAPP_NUMBERS').to_s
    return false if inactive_numbers.blank?

    inactive_numbers_array = inactive_numbers.split(',').map(&:strip)
    inactive_numbers_array.include?(phone_number)
  end
end
