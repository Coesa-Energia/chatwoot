# frozen_string_literal: true

require 'base64'

class Internal::Accounts::MarketingAttributionService
  FIRST_TOUCH_COOKIE = 'cw_first_touch_attribution'
  LAST_TOUCH_COOKIE = 'cw_last_touch_attribution'
  FIELD_MAX_LENGTH = 500
  ALLOWED_FIELDS = %w[
    utm_source
    utm_medium
    utm_campaign
    utm_term
    utm_content
    utm_id
    gclid
    gbraid
    wbraid
    dclid
    fbclid
    msclkid
    ttclid
    li_fat_id
    twclid
    rdt_cid
    referrer
    referrer_path
    landing_page
    source
    source_type
    captured_at
  ].freeze

  pattr_initialize [:account!, :cookies!]

  def perform
    # COESA FORK: atribuição de marketing externa desligada. Retorno fixo.
    true
  end

  private

  def attribution_cookie(cookie_name)
    return if cookies[cookie_name].blank?

    parse_cookie(cookies[cookie_name].to_s)
  end

  def parse_cookie(cookie_value)
    validate_payload(JSON.parse(Base64.urlsafe_decode64(cookie_value)))
  rescue JSON::ParserError, ArgumentError
    nil
  end

  def validate_payload(payload)
    return unless payload.is_a?(Hash)

    payload.slice(*ALLOWED_FIELDS).filter_map do |key, value|
      next if value.blank? || value.is_a?(Array) || value.is_a?(Hash)

      [key, value.to_s.first(FIELD_MAX_LENGTH)]
    end.to_h.presence
  end

  def internal_attributes_service
    @internal_attributes_service ||= Internal::Accounts::InternalAttributesService.new(account)
  end

  def enqueue_signup_conversion
    Internal::Accounts::MarketingConversionTrackingJob.perform_later(account.id, 'cloud_signup', account.created_at)
  end
end
