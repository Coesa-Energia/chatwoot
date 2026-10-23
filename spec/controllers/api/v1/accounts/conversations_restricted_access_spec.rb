require 'rails_helper'

RSpec.describe 'Conversations of an agent restricted to their own', type: :request do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:colleague) { create(:user, account: account, role: :agent) }
  let!(:own) { create(:conversation, account: account, inbox: inbox, assignee: agent) }
  let!(:theirs) { create(:conversation, account: account, inbox: inbox, assignee: colleague) }
  let!(:unassigned) { create(:conversation, account: account, inbox: inbox, assignee: nil) }
  let(:base) { "/api/v1/accounts/#{account.id}/conversations" }

  before do
    create(:inbox_member, inbox: inbox, user: agent, see_all_conversations: false)
    create(:inbox_member, inbox: inbox, user: colleague, see_all_conversations: true)
    create(:message, conversation: theirs, account: account, inbox: inbox, content: 'private to colleague')
  end

  it 'lists only the conversations assigned to them' do
    get base, params: { assignee_type: 'all', status: 'all' }, headers: agent.create_new_auth_token, as: :json

    expect(response.parsed_body.dig('data', 'payload').pluck('id')).to eq([own.display_id])
  end

  it 'shows only their conversations in the counts of the list' do
    get "#{base}/meta", params: { status: 'all' }, headers: agent.create_new_auth_token, as: :json

    expect(response.parsed_body.dig('meta', 'all_count')).to eq(1)
  end

  it 'cannot open, read or change somebody else\'s conversation' do
    get "#{base}/#{theirs.display_id}", headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)

    get "#{base}/#{theirs.display_id}/messages", headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)

    post "#{base}/#{theirs.display_id}/toggle_status", params: { status: 'resolved' }, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)
    expect(theirs.reload).to be_open
  end

  it 'cannot open an unassigned conversation' do
    get "#{base}/#{unassigned.display_id}", headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it 'can open their own conversation' do
    get "#{base}/#{own.display_id}", headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
  end

  it 'gets access to a conversation once added as participant' do
    create(:conversation_participant, conversation: theirs, user: agent, account: account)

    get "#{base}/#{theirs.display_id}", headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
  end

  it 'sees everything after being released' do
    InboxMember.find_by(inbox: inbox, user: agent).update!(see_all_conversations: true)

    get base, params: { assignee_type: 'all', status: 'all' }, headers: agent.create_new_auth_token, as: :json

    expect(response.parsed_body.dig('data', 'payload').pluck('id')).to contain_exactly(own.display_id, theirs.display_id, unassigned.display_id)
  end
end
