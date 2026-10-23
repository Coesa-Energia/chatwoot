require 'rails_helper'

RSpec.describe Api::V1::Accounts::Contacts::CallsController, type: :request do
  let(:account) { create(:account) }
  let(:voice_channel) { create(:channel_twilio_sms, :with_voice, account: account) }
  let(:voice_inbox) { voice_channel.inbox }
  let(:whatsapp_channel) do
    create(:channel_whatsapp, provider: 'whatsapp_cloud', account: account, validate_provider_config: false, sync_templates: false)
  end
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:contact) { create(:contact, account: account, phone_number: '+5511999990000') }
  let!(:whatsapp_conversation) { create(:conversation, account: account, inbox: whatsapp_channel.inbox, contact: contact, status: :open) }
  let(:call_path) { "/api/v1/accounts/#{account.id}/contacts/#{contact.id}/call" }
  let(:call_params) { { inbox_id: voice_inbox.id, conversation_id: whatsapp_conversation.display_id } }

  before do
    allow(Twilio::VoiceWebhookSetupService).to receive(:new)
      .and_return(instance_double(Twilio::VoiceWebhookSetupService, perform: "AP#{SecureRandom.hex(8)}"))
    allow(Voice::Provider::Twilio::Adapter).to receive(:new)
      .and_return(instance_double(Voice::Provider::Twilio::Adapter, initiate_call: { call_sid: 'CAWA1' }))
    create(:inbox_member, inbox: voice_inbox, user: agent)
    create(:inbox_member, inbox: whatsapp_channel.inbox, user: agent)
  end

  it 'logs a phone call started from a WhatsApp conversation in that conversation' do
    expect { post call_path, headers: agent.create_new_auth_token, params: call_params }.not_to change(account.conversations, :count)

    call = Call.find_by!(provider_call_id: 'CAWA1')
    aggregate_failures do
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['conversation_id']).to eq(whatsapp_conversation.display_id)
      expect(response.parsed_body['inbox_id']).to eq(voice_inbox.id)
      expect(call.conversation).to eq(whatsapp_conversation)
      expect(call.inbox).to eq(voice_inbox)
      expect(whatsapp_conversation.messages.voice_calls.last.call).to eq(call)
    end
  end

  it 'opens a voice inbox conversation when the WhatsApp conversation is resolved' do
    whatsapp_conversation.update!(status: :resolved)

    post call_path, headers: agent.create_new_auth_token, params: call_params

    expect(Call.find_by!(provider_call_id: 'CAWA1').conversation.inbox).to eq(voice_inbox)
  end
end
