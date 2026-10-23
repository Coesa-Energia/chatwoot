require 'rails_helper'

describe Whatsapp::ApiVersion do
  describe '.current' do
    it 'follows the WHATSAPP_API_VERSION setting' do
      allow(GlobalConfigService).to receive(:load).with('WHATSAPP_API_VERSION', described_class::DEFAULT).and_return('v25.0')

      expect(described_class.current).to eq('v25.0')
    end

    it 'falls back to the default when nothing is configured' do
      allow(GlobalConfigService).to receive(:load).with('WHATSAPP_API_VERSION', described_class::DEFAULT).and_return(described_class::DEFAULT)

      expect(described_class.current).to eq('v22.0')
    end
  end

  describe 'send, media and template paths' do
    let(:channel) do
      create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false).tap do |record|
        record.provider_config = { 'api_key' => 'key', 'phone_number_id' => '111', 'business_account_id' => '222' }
        record.save!
      end
    end
    let(:service) { Whatsapp::Providers::WhatsappCloudService.new(whatsapp_channel: channel) }

    before { allow(GlobalConfigService).to receive(:load).and_call_original }

    it 'uses the configured version everywhere instead of a pinned one' do
      allow(GlobalConfigService).to receive(:load).with('WHATSAPP_API_VERSION', described_class::DEFAULT).and_return('v25.0')

      expect(service.media_url('999')).to eq('https://graph.facebook.com/v25.0/999')
      expect(service.send(:phone_id_path)).to eq('https://graph.facebook.com/v25.0/111')
      expect(service.send(:business_account_path)).to eq('https://graph.facebook.com/v25.0/222')
    end
  end
end
