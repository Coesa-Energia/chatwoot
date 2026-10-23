require 'rails_helper'

RSpec.describe Whatsapp::ManualWebhookStatusService do
  subject(:service) { described_class.new(channel) }

  let(:channel) do
    create(:channel_whatsapp, phone_number: '+15550001112', provider: 'whatsapp_cloud', sync_templates: false,
                              validate_provider_config: false).tap do |record|
      record.provider_config = { 'api_key' => 'key', 'phone_number_id' => 'pn_2', 'business_account_id' => 'waba_1',
                                 'source' => 'manual_setup_v2' }
      record.save!
    end
  end
  let(:api_client) { instance_double(Whatsapp::FacebookApiClient) }
  let(:webhook_configuration) { {} }

  before do
    allow(Whatsapp::FacebookApiClient).to receive(:new).and_return(api_client)
    allow(api_client).to receive(:fetch_phone_number)
      .with('pn_2', fields: 'webhook_configuration')
      .and_return('webhook_configuration' => webhook_configuration)
    allow(api_client).to receive(:fetch_subscribed_apps).with('waba_1').and_return('data' => [{ 'id' => 'app' }])
    stub_const('ENV', ENV.to_hash.merge('FRONTEND_URL' => 'https://chat.example.com'))
  end

  describe '#perform' do
    it 'reports the callback as configured when the number override matches' do
      webhook_configuration['phone_number'] = 'https://chat.example.com/webhooks/whatsapp/+15550001112'

      expect(service.perform).to include(callback_configured: true, subscription_verified: true)
    end

    it 'accepts a callback shared with another number of the same WABA' do
      webhook_configuration['whatsapp_business_account'] = 'https://chat.example.com/webhooks/whatsapp/+15550001111'

      expect(service.perform[:callback_configured]).to be(true)
    end

    it 'uses the number override over a different WABA callback' do
      webhook_configuration['phone_number'] = 'https://other.example.com/webhooks/whatsapp/+15550001112'
      webhook_configuration['whatsapp_business_account'] = 'https://chat.example.com/webhooks/whatsapp/+15550001112'

      expect(service.perform[:callback_configured]).to be(false)
    end

    it 'rejects a callback on another host' do
      webhook_configuration['application'] = 'https://old.example.com/webhooks/whatsapp/+15550001112'

      expect(service.perform[:callback_configured]).to be(false)
    end

    it 'rejects a callback outside the WhatsApp endpoint' do
      webhook_configuration['application'] = 'https://chat.example.com/webhooks/instagram/x'

      expect(service.perform[:callback_configured]).to be(false)
    end

    it 'reports no callback when nothing is configured' do
      expect(service.perform[:callback_configured]).to be(false)
    end
  end
end
