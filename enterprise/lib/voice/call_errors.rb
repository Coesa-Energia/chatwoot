module Voice::CallErrors
  # Meta WhatsApp Cloud Calling error code returned when the contact has not
  # granted call permission yet. See `initiate_call` in
  # Enterprise::Whatsapp::Providers::WhatsappCloudService.
  NO_CALL_PERMISSION_CODE = 138_006

  # Meta codes that mean "don't ask again right now": retrying the permission request (by any
  # channel, template included) would just hit the same wall.
  PERMISSION_REQUEST_BLOCKED_CODES = [138_009, 138_017].freeze

  # Meta error code => i18n key under errors.whatsapp.calls.meta. Anything not listed falls back to a
  # generic message so the agent never sees raw Graph API text.
  FRIENDLY_KEYS = {
    2 => 'temporary_failure', 131_014 => 'temporary_failure', 138_004 => 'temporary_failure', 613 => 'temporary_failure',
    131_030 => 'test_number', 131_044 => 'payment_method', 131_047 => 'outside_window',
    138_000 => 'calling_disabled', 138_001 => 'recipient_uncallable', 138_002 => 'too_many_calls',
    138_003 => 'already_in_call', 138_005 => 'rate_limited', 138_009 => 'permission_limit',
    138_012 => 'daily_limit', 138_013 => 'not_available', 138_014 => 'quality_blocked',
    138_017 => 'permission_exists', 138_018 => 'not_available'
  }.freeze

  class CallError < StandardError
    attr_reader :code

    def initialize(message = nil, code: nil)
      super(message)
      @code = code
    end
  end

  class NoCallPermission < StandardError; end
  class CallFailed < CallError; end
  # Raised when Meta refuses the permission-request message itself (limits, 24h window, ...).
  class PermissionRequestFailed < CallError; end
  class NotRinging < StandardError; end
  class AlreadyAccepted < StandardError; end
  class CallAlreadyEnded < StandardError; end

  # Plain-language text for a Meta error code. The code is appended to the generic fallback so an
  # administrator can still look it up, while the agent gets something actionable.
  def self.friendly_message(code)
    key = FRIENDLY_KEYS[code.to_i]
    return I18n.t("errors.whatsapp.calls.meta.#{key}") if key

    generic = I18n.t('errors.whatsapp.calls.meta.generic')
    code.present? ? "#{generic} (#{I18n.t('errors.whatsapp.calls.meta.code_label')} #{code})" : generic
  end
end
