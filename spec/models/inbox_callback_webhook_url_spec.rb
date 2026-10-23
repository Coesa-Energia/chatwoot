require 'rails_helper'

# The 360dialog webhook URL carries a secret token. It must only be exposed when explicitly requested
# (administrators), never in the default URL that every agent receives.
RSpec.describe Inbox do
  describe '#callback_webhook_url for WhatsApp channels' do
    let(:base_url) { "#{ENV.fetch('FRONTEND_URL', nil)}/webhooks/whatsapp" }

    context 'with a 360dialog channel' do
      let(:channel) { create(:channel_whatsapp, provider: 'default', sync_templates: false, validate_provider_config: false) }
      let(:inbox) { channel.inbox }

      it 'does not include the secret token by default' do
        expect(inbox.callback_webhook_url).to eq("#{base_url}/#{channel.phone_number}")
      end

      it 'includes the secret token when requested' do
        expect(inbox.callback_webhook_url(include_secret: true))
          .to eq("#{base_url}/#{channel.phone_number}?token=#{channel.provider_config['webhook_secret']}")
      end
    end

    context 'with a WhatsApp Cloud channel' do
      let(:channel) { create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false) }

      it 'never adds a token to the URL' do
        expect(channel.inbox.callback_webhook_url(include_secret: true)).to eq("#{base_url}/#{channel.phone_number}")
      end
    end
  end
end
