require 'rails_helper'

RSpec.describe 'Inbox members conversation access', type: :request do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:supervisor) { create(:user, account: account, role: :agent) }
  let(:url) { "/api/v1/accounts/#{account.id}/inbox_members" }

  it 'adds agents restricted to their own conversations by default' do
    post url, params: { inbox_id: inbox.id, user_ids: [agent.id, supervisor.id] }, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['payload'].pluck('see_all_conversations')).to eq([false, false])
  end

  it 'lets the administrator release one agent to see every conversation of the inbox' do
    post url, params: { inbox_id: inbox.id, user_ids: [agent.id, supervisor.id], see_all_user_ids: [supervisor.id] },
              headers: admin.create_new_auth_token, as: :json

    flags = response.parsed_body['payload'].to_h { |member| [member['id'], member['see_all_conversations']] }
    expect(flags).to eq(agent.id => false, supervisor.id => true)
  end

  it 'changes the release of an existing member and can take it back' do
    inbox.add_members([agent.id])

    patch url, params: { inbox_id: inbox.id, user_ids: [agent.id], see_all_user_ids: [agent.id] }, headers: admin.create_new_auth_token, as: :json
    expect(InboxMember.find_by(inbox: inbox, user: agent).see_all_conversations).to be(true)

    patch url, params: { inbox_id: inbox.id, user_ids: [agent.id], see_all_user_ids: [] }, headers: admin.create_new_auth_token, as: :json
    expect(InboxMember.find_by(inbox: inbox, user: agent).see_all_conversations).to be(false)
  end

  it 'leaves the release untouched when the param is not sent' do
    inbox.add_members([agent.id])
    InboxMember.find_by(inbox: inbox, user: agent).update!(see_all_conversations: true)

    patch url, params: { inbox_id: inbox.id, user_ids: [agent.id] }, headers: admin.create_new_auth_token, as: :json

    expect(InboxMember.find_by(inbox: inbox, user: agent).see_all_conversations).to be(true)
  end

  it 'does not let agents change who sees what' do
    inbox.add_members([agent.id])

    patch url, params: { inbox_id: inbox.id, user_ids: [agent.id], see_all_user_ids: [agent.id] }, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unauthorized)
    expect(InboxMember.find_by(inbox: inbox, user: agent).see_all_conversations).to be(false)
  end
end
