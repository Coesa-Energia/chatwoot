require 'rails_helper'

# 360dialog does not sign webhooks, so the webhook URL registered with them carries the channel's secret token.
describe Whatsapp::Providers::Whatsapp360DialogService do
  let(:channel) { create(:channel_whatsapp, provider: 'default', sync_templates: false, validate_provider_config: false) }

  it 'registers the webhook URL with the channel secret token' do
    expected_url = "#{ENV.fetch('FRONTEND_URL', nil)}/webhooks/whatsapp/#{channel.phone_number}?token=#{channel.provider_config['webhook_secret']}"
    registration = stub_request(:post, %r{/configs/webhook})
                   .with(body: { url: expected_url }.to_json)
                   .to_return(status: 200, body: '{}', headers: { 'Content-Type' => 'application/json' })

    expect(described_class.new(whatsapp_channel: channel).validate_provider_config?).to be(true)
    expect(registration).to have_been_requested
  end
end
