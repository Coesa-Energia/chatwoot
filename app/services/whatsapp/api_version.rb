# Single source for the Graph API version used by the WhatsApp Cloud calls that do not have their own setting.
# It follows the WHATSAPP_API_VERSION installation setting (SuperAdmin > App Settings), so changing the version
# is one edit instead of hunting hard-coded numbers.
module Whatsapp::ApiVersion
  DEFAULT = 'v22.0'.freeze

  def self.current
    GlobalConfigService.load('WHATSAPP_API_VERSION', DEFAULT)
  end
end
