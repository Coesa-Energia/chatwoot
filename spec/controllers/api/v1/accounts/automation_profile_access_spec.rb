require 'rails_helper'

# An automation profile is an account AgentBot without webhook URL: it only acts through its access token.
RSpec.describe 'Automation profile (account bot) API access', type: :request do
  let!(:account) { create(:account) }
  let!(:inbox) { create(:inbox, account: account) }
  let!(:contact) { create(:contact, account: account, phone_number: '+5511999990000') }
  let!(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox) }
  let!(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox) }
  let(:profile) { create(:agent_bot, account: account, outgoing_url: nil) }
  let(:headers) { { api_access_token: profile.access_token.token } }

  it 'creates an account bot without webhook URL' do
    admin = create(:user, account: account, role: :administrator)
    post "/api/v1/accounts/#{account.id}/agent_bots", headers: admin.create_new_auth_token, params: { name: 'Cobrança' }, as: :json

    expect(response).to have_http_status(:success)
    expect(AgentBot.find(response.parsed_body['id']).outgoing_url).to be_blank
  end

  it 'searches and creates contacts in its own account' do
    get "/api/v1/accounts/#{account.id}/contacts/search", params: { q: '+5511999990000' }, headers: headers
    expect(response).to have_http_status(:success)
    expect(response.parsed_body['payload'].pluck('id')).to eq([contact.id])

    post "/api/v1/accounts/#{account.id}/contacts", headers: headers, as: :json,
                                                    params: { inbox_id: inbox.id, name: 'Cliente', phone_number: '+5511988887777' }
    expect(response).to have_http_status(:success)
    expect(account.contacts.find_by(phone_number: '+5511988887777').contact_inboxes.pluck(:inbox_id)).to eq([inbox.id])
  end

  it 'lists conversations and messages in its own account' do
    get "/api/v1/accounts/#{account.id}/contacts/#{contact.id}/conversations", headers: headers
    expect(response).to have_http_status(:success)
    expect(response.parsed_body['payload'].pluck('id')).to eq([conversation.display_id])

    get "/api/v1/accounts/#{account.id}/conversations", params: { inbox_id: inbox.id, status: 'open', sort_by: 'last_activity_at_desc' },
                                                        headers: headers
    expect(response).to have_http_status(:success)
    expect(response.parsed_body['data']['payload'].pluck('id')).to eq([conversation.display_id])

    get "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/messages", headers: headers
    expect(response).to have_http_status(:success)
  end

  it 'sends template messages as the bot' do
    post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/messages",
         headers: headers, as: :json,
         params: { content: 'Seu boleto vence amanhã', message_type: 'outgoing',
                   template_params: { name: 'boleto', category: 'UTILITY', language: 'pt_BR', processed_params: { body: { '1' => 'x' } } } }

    expect(response).to have_http_status(:success)
    message = conversation.messages.last
    expect([message.sender_type, message.sender_id]).to eq(['AgentBot', profile.id])
  end

  it 'starts a conversation with a message sent as the bot' do
    other_contact = create(:contact, account: account)
    post "/api/v1/accounts/#{account.id}/conversations", headers: headers, as: :json,
                                                         params: { source_id: '5511977776666', inbox_id: inbox.id, contact_id: other_contact.id,
                                                                   message: { content: 'Olá' } }

    expect(response).to have_http_status(:success)
    message = account.conversations.find_by(display_id: response.parsed_body['id']).messages.last
    expect([message.sender_type, message.sender_id]).to eq(['AgentBot', profile.id])
  end

  it 'is unauthorized in another account' do
    other_account = create(:account)
    get "/api/v1/accounts/#{other_account.id}/contacts/search", params: { q: 'a' }, headers: headers

    expect(response).to have_http_status(:unauthorized)
  end

  it 'is unauthorized on endpoints that were not opened to bots' do
    get "/api/v1/accounts/#{account.id}/contacts", headers: headers
    expect(response).to have_http_status(:unauthorized)

    delete "/api/v1/accounts/#{account.id}/contacts/#{contact.id}", headers: headers
    expect(response).to have_http_status(:unauthorized)
  end

  it 'does not open the lookups to a global bot connected to an inbox' do
    global_bot = create(:agent_bot)
    create(:agent_bot_inbox, inbox: inbox, agent_bot: global_bot)
    get "/api/v1/accounts/#{account.id}/contacts/search", params: { q: 'a' }, headers: { api_access_token: global_bot.access_token.token }

    expect(response).to have_http_status(:unauthorized)
  end
end
