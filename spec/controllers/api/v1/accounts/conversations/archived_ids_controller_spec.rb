require 'rails_helper'

RSpec.describe 'Archived conversation ids API', type: :request do
  let!(:account) { create(:account) }
  let!(:inbox) { create(:inbox, account: account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:colleague) { create(:user, account: account, role: :agent) }
  let!(:archived) { create(:conversation, inbox: inbox, account: account) }
  let!(:pinned_only) { create(:conversation, inbox: inbox, account: account) }
  let!(:not_archived) { create(:conversation, inbox: inbox, account: account) }
  let(:url) { "/api/v1/accounts/#{account.id}/conversations/archived_ids" }

  before do
    create(:inbox_member, inbox: inbox, user: agent)
    create(:inbox_member, inbox: inbox, user: colleague)
    ConversationUserState.create!(user: agent, conversation: archived, account_id: account.id, archived_at: 1.hour.ago)
    ConversationUserState.create!(user: agent, conversation: pinned_only, account_id: account.id, pinned_at: Time.current)
    ConversationUserState.create!(user: colleague, conversation: not_archived, account_id: account.id, archived_at: 1.hour.ago)
  end

  it 'lists only what the requesting agent archived' do
    get url, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['payload']).to eq([archived.display_id])
  end

  it 'keeps an archived conversation archived after new activity' do
    archived.update_columns(last_activity_at: 1.minute.ago) # rubocop:disable Rails/SkipsModelValidations

    get url, headers: agent.create_new_auth_token, as: :json

    expect(response.parsed_body['payload']).to eq([archived.display_id])
  end

  it 'requires authentication' do
    get url

    expect(response).to have_http_status(:unauthorized)
  end
end
