# Manages the WhatsApp message template used to ask a contact for call permission (a template with
# the `call_permission_request` component). Unlike the free-form interactive request it can be sent
# outside the 24h window and again after the first request. Meta must approve it before it can be sent.
#
# The admin can edit the text before it goes to Meta, or adopt a template that already exists on the WABA by
# typing its name. The category is left to Meta (see SUBMITTED_CATEGORY). The last known state lives in
# provider_config['call_permission_template'].
class Whatsapp::CallPermissionTemplateService
  TEMPLATE_NAME = 'pedido_permissao_ligacao'.freeze
  LANGUAGE = 'pt_BR'.freeze
  # Submitted as UTILITY with allow_category_change: Meta moves it to MARKETING by itself when it reads the
  # text that way, so the admin never has to pick (and a wrong pick no longer gets the template rejected).
  SUBMITTED_CATEGORY = 'UTILITY'.freeze
  CONFIG_KEY = 'call_permission_template'.freeze
  APPROVED = 'APPROVED'.freeze
  NOT_FOUND = 'NOT_FOUND'.freeze
  NAME_FORMAT = /\A[a-z0-9_]{1,512}\z/
  MAX_BODY_LENGTH = 1024
  STALE_AFTER = 5.minutes

  # Raised for input the admin can fix (bad name, empty text, template that is not a call template).
  class InvalidTemplate < StandardError; end

  pattr_initialize [:channel!]

  def name
    stored['name'].presence || TEMPLATE_NAME
  end

  def language
    stored['language'].presence || LANGUAGE
  end

  # What the settings screen shows; no network calls.
  def state
    {
      name: name, language: language, status: stored['status'], category: stored['category'].presence,
      body: stored['body'].presence || default_body, rejected_reason: stored['rejected_reason'],
      default_body: default_body, created: stored.present? && stored['status'] != NOT_FOUND
    }
  end

  # Cheap check for the request flow: trusts the stored status and only re-asks Meta (at most every
  # STALE_AFTER) while the template is still waiting for approval.
  def approved?
    return true if stored['status'] == APPROVED
    return false if stored.blank? || fresh?

    refresh[:status] == APPROVED
  end

  # Sends the template to Meta for review, or adopts it when a template with that name already exists there.
  def create(name: nil, body: nil)
    name = name.to_s.strip.presence || TEMPLATE_NAME
    body = body.to_s.strip.presence || default_body
    validate!(name, body)

    existing = provider.find_message_template(name)
    return adopt(existing) if existing

    provider.create_call_permission_template(name: name, language: LANGUAGE, body: body, category: SUBMITTED_CATEGORY)
    persist(name: name, language: LANGUAGE, status: 'PENDING', body: body, category: SUBMITTED_CATEGORY)
  end

  # Re-reads the approval status (and the text Meta has) from Meta.
  def refresh
    existing = provider.find_message_template(name)
    return persist(stored.symbolize_keys.merge(status: NOT_FOUND, rejected_reason: nil)) if existing.nil?

    adopt(existing)
  end

  private

  def provider
    @provider ||= channel.provider_service
  end

  def stored
    channel.provider_config&.dig(CONFIG_KEY) || {}
  end

  def fresh?
    checked_at = stored['checked_at']
    checked_at.present? && Time.zone.parse(checked_at) > STALE_AFTER.ago
  end

  def adopt(template)
    components = Array(template['components'])
    unless components.any? { |component| component['type'].to_s.casecmp?('call_permission_request') }
      raise InvalidTemplate, I18n.t('errors.whatsapp.calls.template.not_call_template', name: template['name'])
    end

    persist(
      name: template['name'], language: template['language'], status: template['status'], category: template['category'],
      body: components.find { |component| component['type'].to_s.casecmp?('body') }&.dig('text'),
      rejected_reason: template['rejected_reason'].presence
    )
  end

  def persist(attrs)
    attrs = attrs.symbolize_keys
    data = {
      'name' => attrs[:name], 'language' => attrs[:language], 'status' => attrs[:status], 'category' => attrs[:category],
      'body' => attrs[:body], 'rejected_reason' => attrs[:rejected_reason], 'checked_at' => Time.current.iso8601
    }.compact
    channel.provider_config = (channel.provider_config || {}).merge(CONFIG_KEY => data)
    channel.save!(validate: false)
    state
  end

  def validate!(name, body)
    raise InvalidTemplate, I18n.t('errors.whatsapp.calls.template.invalid_name') unless name.match?(NAME_FORMAT)
    raise InvalidTemplate, I18n.t('errors.whatsapp.calls.template.body_variables') if body.match?(/\{\{.*?\}\}/)
    raise InvalidTemplate, I18n.t('errors.whatsapp.calls.template.body_too_long', max: MAX_BODY_LENGTH) if body.length > MAX_BODY_LENGTH
  end

  def default_body
    I18n.with_locale(:pt_BR) { I18n.t('conversations.messages.whatsapp.call_permission_template_body') }
  end
end
