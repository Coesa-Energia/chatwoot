require 'rails_helper'

describe Whatsapp::Providers::WhatsappCloudService do
  subject(:service) { described_class.new(whatsapp_channel: whatsapp_channel) }

  let(:whatsapp_channel) { create(:channel_whatsapp, provider: 'whatsapp_cloud', validate_provider_config: false, sync_templates: false) }
  # Call-flow endpoints use the configured WHATSAPP_API_VERSION (fallback v22.0),
  # not the OSS v13.0 path locked for legacy /messages compatibility.
  let(:calls_url) { 'https://graph.facebook.com/v22.0/123456789/calls' }
  let(:messages_url) { 'https://graph.facebook.com/v22.0/123456789/messages' }
  let(:headers) { { 'Content-Type' => 'application/json' } }

  before { stub_request(:get, /message_templates/) }

  describe 'call action methods' do
    it 'POSTs the action body with the SDP answer and returns true on success' do
      stub_request(:post, calls_url)
        .with(body: { messaging_product: 'whatsapp', call_id: 'WACALL', action: 'pre_accept',
                      session: { sdp: 'sdp_answer', sdp_type: 'answer' } }.to_json)
        .to_return(status: 200, body: '{}', headers: headers)

      expect(service.pre_accept_call('WACALL', 'sdp_answer')).to be true
    end

    it 'returns false when Meta responds with a non-success status' do
      stub_request(:post, calls_url).to_return(status: 400, body: '{}', headers: headers)

      expect(service.reject_call('WACALL')).to be false
    end
  end

  describe '#send_call_permission_request' do
    it 'returns the parsed body on success' do
      stub_request(:post, messages_url)
        .with(body: hash_including(messaging_product: 'whatsapp', to: '15551234567', type: 'interactive'))
        .to_return(status: 200, body: { messages: [{ id: 'wamid' }] }.to_json, headers: headers)

      expect(service.send_call_permission_request('15551234567')).to eq('messages' => [{ 'id' => 'wamid' }])
    end

    it 'uses recipient for a BSUID' do
      stub_request(:post, messages_url)
        .with(body: hash_including(messaging_product: 'whatsapp', recipient: 'IN.2081978709342942', type: 'interactive'))
        .to_return(status: 200, body: { messages: [{ id: 'wamid' }] }.to_json, headers: headers)

      service.send_call_permission_request('IN.2081978709342942')

      expect(a_request(:post, messages_url).with { |request| JSON.parse(request.body).exclude?('to') }).to have_been_made
    end
  end

  describe '#initiate_call' do
    it 'returns the parsed body on success' do
      stub_request(:post, calls_url)
        .with(body: { messaging_product: 'whatsapp', to: '15551234567', action: 'connect',
                      session: { sdp: 'sdp_offer', sdp_type: 'offer' } }.to_json)
        .to_return(status: 200, body: { messages: [{ id: 'wacall_1' }] }.to_json, headers: headers)

      expect(service.initiate_call('15551234567', 'sdp_offer')).to eq('messages' => [{ 'id' => 'wacall_1' }])
    end

    it 'uses recipient for a BSUID' do
      stub_request(:post, calls_url)
        .with(body: { messaging_product: 'whatsapp', recipient: 'IN.2081978709342942', action: 'connect',
                      session: { sdp: 'sdp_offer', sdp_type: 'offer' } }.to_json)
        .to_return(status: 200, body: { calls: [{ id: 'wacall_bsuid' }] }.to_json, headers: headers)

      expect(service.initiate_call('IN.2081978709342942', 'sdp_offer')).to eq('calls' => [{ 'id' => 'wacall_bsuid' }])
    end

    it 'raises Voice::CallErrors::NoCallPermission when Meta returns error code 138006' do
      stub_request(:post, calls_url).to_return(
        status: 400,
        body: { error: { code: 138_006, error_user_msg: 'No call permission' } }.to_json,
        headers: headers
      )

      expect { service.initiate_call('15551234567', 'sdp_offer') }
        .to raise_error(Voice::CallErrors::NoCallPermission, 'No call permission')
    end

    it 'raises Voice::CallErrors::CallFailed with a plain-language fallback when the error body is non-JSON' do
      stub_request(:post, calls_url).to_return(status: 502, body: '<html>502 Bad Gateway</html>',
                                               headers: { 'Content-Type' => 'text/html' })

      expect { service.initiate_call('15551234567', 'sdp_offer') }
        .to raise_error(Voice::CallErrors::CallFailed, I18n.t('errors.whatsapp.calls.meta.generic'))
    end

    it 'translates known Meta codes into readable messages and keeps the code' do
      stub_request(:post, calls_url).to_return(
        status: 400, body: { error: { code: 131_014, message: 'Request processing error' } }.to_json, headers: headers
      )

      expect { service.initiate_call('15551234567', 'sdp_offer') }.to raise_error(Voice::CallErrors::CallFailed) do |error|
        expect(error.message).to eq(I18n.t('errors.whatsapp.calls.meta.temporary_failure'))
        expect(error.code).to eq(131_014)
      end
    end
  end

  describe 'permission request failures' do
    it 'raises PermissionRequestFailed with a readable message when Meta refuses the request' do
      stub_request(:post, messages_url).to_return(status: 400, body: { error: { code: 138_009 } }.to_json, headers: headers)

      expect { service.send_call_permission_request('15551234567') }.to raise_error(Voice::CallErrors::PermissionRequestFailed) do |error|
        expect(error.message).to eq(I18n.t('errors.whatsapp.calls.meta.permission_limit'))
        expect(error.code).to eq(138_009)
      end
    end
  end

  describe '#send_call_permission_template' do
    it 'sends the template message to the recipient' do
      stub_request(:post, messages_url)
        .with(body: hash_including(type: 'template', to: '15551234567', template: { name: 'tpl', language: { code: 'pt_BR' } }))
        .to_return(status: 200, body: { messages: [{ id: 'wamid.tpl' }] }.to_json, headers: headers)

      expect(service.send_call_permission_template('15551234567', 'tpl', 'pt_BR')).to eq('messages' => [{ 'id' => 'wamid.tpl' }])
    end
  end

  describe '#create_call_permission_template' do
    let(:templates_url) { "https://graph.facebook.com/v22.0/#{whatsapp_channel.provider_config['business_account_id']}/message_templates" }

    it 'posts a BODY plus call_permission_request component and lets Meta change the category' do
      stub_request(:post, templates_url).to_return(status: 200, body: { id: '1', status: 'PENDING' }.to_json, headers: headers)

      service.create_call_permission_template(name: 'tpl', language: 'pt_BR', body: 'Oi')

      expect(a_request(:post, templates_url).with do |request|
        body = JSON.parse(request.body)
        body['allow_category_change'] == true &&
          body['components'] == [{ 'type' => 'BODY', 'text' => 'Oi' }, { 'type' => 'call_permission_request' }]
      end).to have_been_made
    end
  end

  describe '#fetch_call_permissions' do
    let(:permissions_url) { 'https://graph.facebook.com/v22.0/123456789/call_permissions' }

    it 'queries by user_wa_id' do
      stub_request(:get, permissions_url).with(query: { user_wa_id: '15551234567' })
                                         .to_return(status: 200, body: { permission: { status: 'temporary' } }.to_json, headers: headers)

      expect(service.fetch_call_permissions('15551234567')).to eq('permission' => { 'status' => 'temporary' })
    end

    it 'queries by recipient for a BSUID' do
      stub_request(:get, permissions_url).with(query: { recipient: 'IN.2081978709342942' })
                                         .to_return(status: 200, body: { permission: { status: 'no_permission' } }.to_json, headers: headers)

      expect(service.fetch_call_permissions('IN.2081978709342942')['permission']['status']).to eq('no_permission')
    end
  end
end
