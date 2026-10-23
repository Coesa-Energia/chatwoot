require 'rails_helper'

describe Whatsapp::FacebookApiClient do
  let(:access_token) { 'test_access_token' }
  let(:api_client) { described_class.new(access_token) }
  let(:api_version) { 'v22.0' }
  let(:app_id) { 'test_app_id' }
  let(:app_secret) { 'test_app_secret' }

  before do
    allow(GlobalConfigService).to receive(:load).with('WHATSAPP_API_VERSION', 'v22.0').and_return(api_version)
    allow(GlobalConfigService).to receive(:load).with('WHATSAPP_APP_ID', '').and_return(app_id)
    allow(GlobalConfigService).to receive(:load).with('WHATSAPP_APP_SECRET', '').and_return(app_secret)
  end

  describe '#exchange_code_for_token' do
    let(:code) { 'test_code' }

    context 'when successful' do
      before do
        stub_request(:get, "https://graph.facebook.com/#{api_version}/oauth/access_token")
          .with(query: { client_id: app_id, client_secret: app_secret, code: code })
          .to_return(
            status: 200,
            body: { access_token: 'new_token' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns the response data' do
        result = api_client.exchange_code_for_token(code)
        expect(result['access_token']).to eq('new_token')
      end
    end

    context 'when failed' do
      before do
        stub_request(:get, "https://graph.facebook.com/#{api_version}/oauth/access_token")
          .with(query: { client_id: app_id, client_secret: app_secret, code: code })
          .to_return(status: 400, body: { error: 'Invalid code' }.to_json)
      end

      it 'raises an error' do
        expect { api_client.exchange_code_for_token(code) }.to raise_error(/Token exchange failed/)
      end
    end
  end

  describe '#fetch_phone_numbers' do
    let(:waba_id) { 'test_waba_id' }

    context 'when successful' do
      before do
        stub_request(:get, "https://graph.facebook.com/#{api_version}/#{waba_id}/phone_numbers")
          .with(query: { access_token: access_token })
          .to_return(
            status: 200,
            body: { data: [{ id: '123', display_phone_number: '1234567890' }] }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns the phone numbers data' do
        result = api_client.fetch_phone_numbers(waba_id)
        expect(result['data']).to be_an(Array)
        expect(result['data'].first['id']).to eq('123')
      end
    end

    context 'when failed' do
      before do
        stub_request(:get, "https://graph.facebook.com/#{api_version}/#{waba_id}/phone_numbers")
          .with(query: { access_token: access_token })
          .to_return(status: 403, body: { error: 'Access denied' }.to_json)
      end

      it 'raises an error' do
        expect { api_client.fetch_phone_numbers(waba_id) }.to raise_error(/WABA phone numbers fetch failed/)
      end
    end
  end

  describe '#debug_token' do
    let(:input_token) { 'test_input_token' }
    let(:app_access_token) { "#{app_id}|#{app_secret}" }

    context 'when successful' do
      before do
        stub_request(:get, "https://graph.facebook.com/#{api_version}/debug_token")
          .with(query: { input_token: input_token, access_token: app_access_token })
          .to_return(
            status: 200,
            body: { data: { app_id: app_id, is_valid: true } }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns the debug token data' do
        result = api_client.debug_token(input_token)
        expect(result['data']['is_valid']).to be(true)
      end
    end

    context 'when failed' do
      before do
        stub_request(:get, "https://graph.facebook.com/#{api_version}/debug_token")
          .with(query: { input_token: input_token, access_token: app_access_token })
          .to_return(status: 400, body: { error: 'Invalid token' }.to_json)
      end

      it 'raises an error' do
        expect { api_client.debug_token(input_token) }.to raise_error(/Token validation failed/)
      end
    end
  end

  describe '#register_phone_number' do
    let(:phone_number_id) { 'test_phone_id' }
    let(:pin) { '123456' }

    context 'when successful' do
      before do
        stub_request(:post, "https://graph.facebook.com/#{api_version}/#{phone_number_id}/register")
          .with(
            headers: { 'Authorization' => "Bearer #{access_token}", 'Content-Type' => 'application/json' },
            body: { messaging_product: 'whatsapp', pin: pin }.to_json
          )
          .to_return(
            status: 200,
            body: { success: true }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns success response' do
        result = api_client.register_phone_number(phone_number_id, pin)
        expect(result['success']).to be(true)
      end
    end

    context 'when failed' do
      before do
        stub_request(:post, "https://graph.facebook.com/#{api_version}/#{phone_number_id}/register")
          .with(
            headers: { 'Authorization' => "Bearer #{access_token}", 'Content-Type' => 'application/json' },
            body: { messaging_product: 'whatsapp', pin: pin }.to_json
          )
          .to_return(status: 400, body: { error: 'Registration failed' }.to_json)
      end

      it 'raises an error' do
        expect { api_client.register_phone_number(phone_number_id, pin) }.to raise_error(/Phone registration failed/)
      end
    end
  end

  describe '#deregister_phone_number' do
    let(:phone_number_id) { 'test_phone_id' }

    context 'when successful' do
      before do
        stub_request(:post, "https://graph.facebook.com/#{api_version}/#{phone_number_id}/deregister")
          .with(headers: { 'Authorization' => "Bearer #{access_token}", 'Content-Type' => 'application/json' })
          .to_return(status: 200, body: { success: true }.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns success response' do
        result = api_client.deregister_phone_number(phone_number_id)
        expect(result['success']).to be(true)
      end
    end

    context 'when failed' do
      before do
        stub_request(:post, "https://graph.facebook.com/#{api_version}/#{phone_number_id}/deregister")
          .to_return(status: 400, body: { error: 'Deregistration failed' }.to_json)
      end

      it 'raises an error' do
        expect { api_client.deregister_phone_number(phone_number_id) }.to raise_error(/Phone deregistration failed/)
      end
    end
  end

  describe '#subscribe_phone_number_webhook' do
    let(:waba_id) { 'test_waba_id' }
    let(:phone_number_id) { 'test_phone_id' }
    let(:callback_url) { 'https://example.com/webhook' }
    let(:verify_token) { 'test_verify_token' }
    let(:json_headers) { { 'Content-Type' => 'application/json' } }
    let(:auth_headers) { { 'Authorization' => "Bearer #{access_token}", 'Content-Type' => 'application/json' } }
    let(:subscribed_apps_url) { "https://graph.facebook.com/#{api_version}/#{waba_id}/subscribed_apps" }
    let(:subscribed_apps_body) { { data: [{ whatsapp_business_api_data: { id: app_id, name: 'App' }, override_callback_uri: 'https://prod.example.com/x' }] } }
    let!(:override_stub) do
      stub_request(:post, "https://graph.facebook.com/#{api_version}/#{phone_number_id}")
        .with(headers: auth_headers,
              body: { webhook_configuration: { override_callback_uri: callback_url, verify_token: verify_token } }.to_json)
        .to_return(status: 200, body: { success: true }.to_json, headers: json_headers)
    end

    def stub_subscribed_apps_list(body)
      stub_request(:get, subscribed_apps_url).with(headers: auth_headers).to_return(status: 200, body: body.to_json, headers: json_headers)
    end

    def stub_subscribe_post(fields)
      stub_request(:post, subscribed_apps_url)
        .with(headers: auth_headers, body: { subscribed_fields: fields }.to_json)
        .to_return(status: 200, body: { success: true }.to_json, headers: json_headers)
    end

    context 'when the app is not subscribed to the WABA yet' do
      it 'subscribes it with the default fields and then sets the number callback' do
        stub_subscribed_apps_list(data: [])
        subscribe_stub = stub_subscribe_post(%w[messages smb_message_echoes])

        result = api_client.subscribe_phone_number_webhook(waba_id, phone_number_id, callback_url, verify_token)

        expect(result['success']).to be(true)
        expect(subscribe_stub).to have_been_requested
        expect(override_stub).to have_been_requested
      end
    end

    context 'when the app is already subscribed to the WABA' do
      before { stub_subscribed_apps_list(subscribed_apps_body) }

      it 'only sets the number callback and never rewrites the WABA subscription' do
        subscribe_stub = stub_subscribe_post(%w[messages smb_message_echoes])

        api_client.subscribe_phone_number_webhook(waba_id, phone_number_id, callback_url, verify_token)

        expect(subscribe_stub).not_to have_been_requested
        expect(override_stub).to have_been_requested
      end

      it 'posts the subscription when calls has to be added to the fields' do
        fields = %w[messages smb_message_echoes calls]
        subscribe_stub = stub_subscribe_post(fields)

        api_client.subscribe_phone_number_webhook(waba_id, phone_number_id, callback_url, verify_token, subscribed_fields: fields)

        expect(subscribe_stub).to have_been_requested
        expect(override_stub).to have_been_requested
      end
    end

    context 'when only another app is subscribed to the WABA' do
      it 'subscribes our app' do
        stub_subscribed_apps_list(data: [{ whatsapp_business_api_data: { id: 'another_app_id' } }])
        subscribe_stub = stub_subscribe_post(%w[messages smb_message_echoes])

        api_client.subscribe_phone_number_webhook(waba_id, phone_number_id, callback_url, verify_token)

        expect(subscribe_stub).to have_been_requested
      end
    end

    context 'when the subscriptions of the WABA cannot be read' do
      it 'falls back to subscribing the app' do
        stub_request(:get, subscribed_apps_url).to_return(status: 500, body: { error: 'boom' }.to_json)
        subscribe_stub = stub_subscribe_post(%w[messages smb_message_echoes])

        api_client.subscribe_phone_number_webhook(waba_id, phone_number_id, callback_url, verify_token)

        expect(subscribe_stub).to have_been_requested
      end
    end

    context 'when app subscription fails' do
      it 'raises an error' do
        stub_subscribed_apps_list(data: [])
        stub_request(:post, subscribed_apps_url).with(headers: auth_headers)
                                                .to_return(status: 400, body: { error: 'App subscription to WABA failed' }.to_json)

        expect do
          api_client.subscribe_phone_number_webhook(waba_id, phone_number_id, callback_url, verify_token)
        end.to raise_error(/App subscription to WABA failed/)
      end
    end

    context 'when phone number callback override fails' do
      it 'raises an error' do
        stub_subscribed_apps_list(subscribed_apps_body)
        stub_request(:post, "https://graph.facebook.com/#{api_version}/#{phone_number_id}")
          .with(headers: auth_headers,
                body: { webhook_configuration: { override_callback_uri: callback_url, verify_token: verify_token } }.to_json)
          .to_return(status: 400, body: { error: 'Phone number webhook callback override failed' }.to_json)

        expect do
          api_client.subscribe_phone_number_webhook(waba_id, phone_number_id, callback_url, verify_token)
        end.to raise_error(/Phone number webhook callback override failed/)
      end
    end
  end

  describe '#clear_phone_number_callback_override' do
    let(:phone_number_id) { 'test_phone_id' }

    context 'when successful' do
      before do
        stub_request(:post, "https://graph.facebook.com/#{api_version}/#{phone_number_id}")
          .with(
            headers: { 'Authorization' => "Bearer #{access_token}", 'Content-Type' => 'application/json' },
            body: { webhook_configuration: { override_callback_uri: '' } }.to_json
          )
          .to_return(
            status: 200,
            body: { success: true }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns success response' do
        result = api_client.clear_phone_number_callback_override(phone_number_id)
        expect(result['success']).to be(true)
      end
    end

    context 'when failed' do
      before do
        stub_request(:post, "https://graph.facebook.com/#{api_version}/#{phone_number_id}")
          .with(
            headers: { 'Authorization' => "Bearer #{access_token}", 'Content-Type' => 'application/json' },
            body: { webhook_configuration: { override_callback_uri: '' } }.to_json
          )
          .to_return(status: 400, body: { error: 'Phone number webhook callback clear failed' }.to_json)
      end

      it 'raises an error' do
        expect { api_client.clear_phone_number_callback_override(phone_number_id) }.to raise_error(/Phone number webhook callback clear failed/)
      end
    end
  end
end
