require 'rails_helper'

# Opening a WhatsApp conversation triggers the read receipt job; other channels do not.
RSpec.describe 'Conversations update_last_seen read receipt', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }

  def mark_seen(conversation)
    post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/update_last_seen",
         headers: agent.create_new_auth_token, as: :json
  end

  it 'enqueues the read receipt job for WhatsApp conversations' do
    channel = create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
    create(:inbox_member, inbox: channel.inbox, user: agent)
    conversation = create(:conversation, inbox: channel.inbox, account: account)

    expect { mark_seen(conversation) }.to have_enqueued_job(Whatsapp::ReadReceiptJob).with(conversation.id)
    expect(response).to have_http_status(:success)
  end

  it 'does not enqueue it for other channels' do
    inbox = create(:inbox, account: account)
    create(:inbox_member, inbox: inbox, user: agent)
    conversation = create(:conversation, inbox: inbox, account: account)

    expect { mark_seen(conversation) }.not_to have_enqueued_job(Whatsapp::ReadReceiptJob)
  end

  it 'does not send a read receipt when the agent marks the conversation as unread' do
    channel = create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
    create(:inbox_member, inbox: channel.inbox, user: agent)
    conversation = create(:conversation, inbox: channel.inbox, account: account)
    create(:message, conversation: conversation, inbox: channel.inbox, account: account, message_type: :incoming)

    expect do
      post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/unread", headers: agent.create_new_auth_token, as: :json
    end.not_to have_enqueued_job(Whatsapp::ReadReceiptJob)
  end
end
