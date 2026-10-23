require 'rails_helper'

# Meta can batch several messages/statuses in one webhook; each must reach the pipeline.
RSpec.describe 'Webhooks::WhatsappController batched payloads', type: :request do
  let(:channel) { create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false) }
  let(:client_secret) { 'test-whatsapp-secret' }
  let(:metadata) { { display_phone_number: channel.phone_number.delete('+'), phone_number_id: '123' } }

  def post_signed(payload)
    body = payload.to_json
    signature = "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', client_secret, body)}"
    with_modified_env WHATSAPP_APP_SECRET: client_secret do
      post "/webhooks/whatsapp/#{channel.phone_number}",
           params: body,
           headers: { 'CONTENT_TYPE' => 'application/json', 'X-Hub-Signature-256' => signature }
    end
  end

  def payload_with(**value)
    { object: 'whatsapp_business_account', entry: [{ id: 'WABA', changes: [{ field: 'messages', value: { metadata: metadata, **value } }] }] }
  end

  before do
    InstallationConfig.where(name: 'WHATSAPP_APP_SECRET').delete_all
    GlobalConfig.clear_cache
  end

  it 'enqueues one job per message when several messages are batched' do
    payload = payload_with(
      contacts: [{ wa_id: '5511999990001' }, { wa_id: '5511999990002' }],
      messages: [
        { id: 'wamid.1', from: '5511999990001', type: 'text', text: { body: 'a' } },
        { id: 'wamid.2', from: '5511999990002', type: 'text', text: { body: 'b' } }
      ]
    )

    expect { post_signed(payload) }.to have_enqueued_job(Webhooks::WhatsappEventsJob).exactly(2).times
    expect(response).to have_http_status(:ok)
  end

  it 'enqueues a single job for a single-message payload' do
    payload = payload_with(
      contacts: [{ wa_id: '5511999990001' }],
      messages: [{ id: 'wamid.1', from: '5511999990001', type: 'text', text: { body: 'a' } }]
    )

    expect { post_signed(payload) }.to have_enqueued_job(Webhooks::WhatsappEventsJob).exactly(1).times
  end

  it 'enqueues one job per status when several statuses are batched' do
    payload = payload_with(statuses: [{ id: 'wamid.1', status: 'delivered' }, { id: 'wamid.2', status: 'read' }])

    expect { post_signed(payload) }.to have_enqueued_job(Webhooks::WhatsappEventsJob).exactly(2).times
  end
end
