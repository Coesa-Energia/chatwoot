require 'rails_helper'

describe Whatsapp::CallPermissionStatusService do
  let(:channel) { create(:channel_whatsapp, provider: 'whatsapp_cloud', validate_provider_config: false, sync_templates: false) }
  let(:provider_service) { instance_double(Whatsapp::Providers::WhatsappCloudService) }

  before { allow(Whatsapp::Providers::WhatsappCloudService).to receive(:new).and_return(provider_service) }

  it 'reduces a temporary permission to what the dashboard needs' do
    allow(provider_service).to receive(:fetch_call_permissions).with('15551234567').and_return(
      'permission' => { 'status' => 'temporary', 'expiration_time' => 1_900_000_000 },
      'actions' => [
        { 'action_name' => 'start_call', 'can_perform_action' => true },
        { 'action_name' => 'send_call_permission_request', 'can_perform_action' => false,
          'limits' => [{ 'time_period' => 'PT24H', 'max_allowed' => 1, 'current_usage' => 1, 'limit_expiration_time' => 1_800_000_000 }] }
      ]
    )

    result = described_class.new(channel: channel, recipient: '15551234567').perform

    expect(result).to include(status: 'temporary', expires_at: 1_900_000_000, can_call: true,
                              can_request: false, request_limit_reset_at: 1_800_000_000)
  end

  it 'reports no permission' do
    allow(provider_service).to receive(:fetch_call_permissions)
      .and_return('permission' => { 'status' => 'no_permission' }, 'actions' => [])

    result = described_class.new(channel: channel, recipient: '15551234567').perform

    expect(result).to include(status: 'no_permission', can_call: false, can_request: true)
  end

  it 'returns unknown with the readable error when Meta fails' do
    allow(provider_service).to receive(:fetch_call_permissions).and_raise(Voice::CallErrors::CallFailed.new('boom', code: 2))

    expect(described_class.new(channel: channel, recipient: '1').perform).to eq(status: 'unknown', error: 'boom')
  end
end
