require 'rails_helper'

RSpec.describe 'Inbox default team', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:team) { create(:team, account: account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:url) { "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}" }

  it 'sets the default team of an inbox and exposes it' do
    patch url, params: { default_team_id: team.id }, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['default_team_id']).to eq(team.id)
    expect(inbox.reload.default_team).to eq(team)
  end

  it 'removes the default team' do
    inbox.update!(default_team: team)

    patch url, params: { default_team_id: nil }, headers: admin.create_new_auth_token, as: :json

    expect(inbox.reload.default_team_id).to be_nil
  end

  it 'rejects a team from another account' do
    patch url, params: { default_team_id: create(:team).id }, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(inbox.reload.default_team_id).to be_nil
  end
end
