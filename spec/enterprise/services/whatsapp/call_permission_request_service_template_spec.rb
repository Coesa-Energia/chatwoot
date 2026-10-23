require 'rails_helper'

describe Whatsapp::CallPermissionRequestService do
  let(:account) { create(:account) }
  let(:channel) do
    create(:channel_whatsapp, provider: 'whatsapp_cloud', account: account,
                              validate_provider_config: false, sync_templates: false)
  end
  let(:inbox) { channel.inbox }
  let(:contact) { create(:contact, account: account, phone_number: '+15551234567') }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox, source_id: '15551234567') }
  let(:conversation) do
    create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox).tap(&:reload)
  end
  let(:provider_service) { instance_double(Whatsapp::Providers::WhatsappCloudService) }
  let(:approved_template) do
    { 'call_permission_template' => { 'name' => 'tpl', 'language' => 'pt_BR', 'status' => 'APPROVED',
                                      'checked_at' => Time.current.iso8601 } }
  end

  before do
    allow(Whatsapp::Providers::WhatsappCloudService).to receive(:new).and_return(provider_service)
    allow(Conversations::ActivityMessageJob).to receive(:perform_later)
  end

  def customer_writes!
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming)
  end

  def approve_template!
    channel.update!(provider_config: channel.provider_config.merge(approved_template))
  end

  it 'falls back to the approved template when the interactive request is refused outside the 24h window' do
    customer_writes!
    approve_template!
    allow(provider_service).to receive(:send_call_permission_request)
      .and_raise(Voice::CallErrors::PermissionRequestFailed.new('window', code: 131_047))
    allow(provider_service).to receive(:send_call_permission_template)
      .with('15551234567', 'tpl', 'pt_BR').and_return({ 'messages' => [{ 'id' => 'wamid.tpl' }] })

    status = described_class.new(conversation: conversation, recipient: '15551234567').perform

    expect(status).to eq('permission_requested')
    expect(conversation.reload.additional_attributes['call_permission_request_message_id']).to eq('wamid.tpl')
  end

  it 'sends a repeated request through the template' do
    customer_writes!
    approve_template!
    conversation.update!(additional_attributes: (conversation.additional_attributes || {}).merge(
      'call_permission_requests' => { '15551234567' => { 'call_permission_requested_at' => 10.minutes.ago.iso8601,
                                                         'call_permission_request_message_id' => 'wamid.first' } }
    ))
    allow(provider_service).to receive(:send_call_permission_request)
    allow(provider_service).to receive(:send_call_permission_template).and_return({ 'messages' => [{ 'id' => 'wamid.second' }] })

    status = described_class.new(conversation: conversation, recipient: '15551234567').perform

    expect(status).to eq('permission_requested')
    expect(provider_service).to have_received(:send_call_permission_template).once
    expect(provider_service).not_to have_received(:send_call_permission_request)
  end

  it 'does not try the template when the template is not approved' do
    customer_writes!
    allow(provider_service).to receive(:send_call_permission_request)
      .and_raise(Voice::CallErrors::PermissionRequestFailed.new('window', code: 131_047))
    allow(provider_service).to receive(:send_call_permission_template)

    service = described_class.new(conversation: conversation, recipient: '15551234567')

    expect(service.perform).to eq('failed')
    expect(service.error_message).to eq('window')
    expect(provider_service).not_to have_received(:send_call_permission_template)
  end

  it 'stops after Meta reports the request limit was reached' do
    customer_writes!
    approve_template!
    allow(provider_service).to receive(:send_call_permission_request)
      .and_raise(Voice::CallErrors::PermissionRequestFailed.new('limit', code: 138_009))
    allow(provider_service).to receive(:send_call_permission_template)

    service = described_class.new(conversation: conversation, recipient: '15551234567')

    expect(service.perform).to eq('failed')
    expect(service.error_message).to eq('limit')
    expect(provider_service).not_to have_received(:send_call_permission_template)
  end

  it 'sends the template straight away when the customer never wrote' do
    approve_template!
    allow(provider_service).to receive(:send_call_permission_request)
    allow(provider_service).to receive(:send_call_permission_template)
      .with('15551234567', 'tpl', 'pt_BR').and_return({ 'messages' => [{ 'id' => 'wamid.tpl' }] })

    status = described_class.new(conversation: conversation, recipient: '15551234567').perform

    expect(status).to eq('permission_requested')
    expect(provider_service).not_to have_received(:send_call_permission_request)
  end

  it 'explains what is missing when the customer never wrote and the template is not approved' do
    allow(provider_service).to receive(:send_call_permission_request)
    allow(provider_service).to receive(:send_call_permission_template)

    service = described_class.new(conversation: conversation, recipient: '15551234567')

    expect(service.perform).to eq('failed')
    expect(service.error_message).to eq(I18n.t('errors.whatsapp.calls.meta.outside_window'))
    expect(provider_service).not_to have_received(:send_call_permission_request)
    expect(provider_service).not_to have_received(:send_call_permission_template)
  end
end
