require 'rails_helper'

RSpec.describe Channel::Whatsapp do
  let(:account) { create(:account).tap { |a| a.enable_features('channel_voice') && a.save! } }
  let(:channel) do
    create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', validate_provider_config: false, sync_templates: false)
  end
  let(:provider_service) { instance_double(Whatsapp::Providers::WhatsappCloudService, update_calling_status: true) }
  let(:webhook_setup_service) { instance_double(Whatsapp::WebhookSetupService, register_callback: true) }

  before do
    allow(channel).to receive(:provider_service).and_return(provider_service)
    allow(channel).to receive(:webhook_setup_service).and_return(webhook_setup_service)
  end

  describe '#enable_voice_calling!' do
    it 'turns receiving calls on together with calling, even if it was muted before' do
      channel.update!(provider_config: channel.provider_config.merge('inbound_calls_enabled' => false))

      channel.enable_voice_calling!

      expect(channel.reload.provider_config).to include('calling_enabled' => true, 'inbound_calls_enabled' => true)
    end
  end
end
