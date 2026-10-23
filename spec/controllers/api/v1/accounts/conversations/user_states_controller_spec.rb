require 'rails_helper'

# Pin / archive a conversation for the current agent only.
RSpec.describe 'Conversation user state API', type: :request do
  let!(:account) { create(:account) }
  let!(:inbox) { create(:inbox, account: account) }
  let!(:conversation) { create(:conversation, inbox: inbox, account: account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:colleague) { create(:user, account: account, role: :agent) }

  before do
    create(:inbox_member, inbox: inbox, user: agent)
    create(:inbox_member, inbox: inbox, user: colleague)
  end

  def update_state(user: agent, target: conversation, **params)
    patch "/api/v1/accounts/#{account.id}/conversations/#{target.display_id}/user_state",
          params: params, headers: user.create_new_auth_token, as: :json
  end

  context 'when unauthenticated' do
    it 'returns unauthorized' do
      patch "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/user_state", params: { pinned: true }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  context 'when the agent has no access to the inbox' do
    it 'returns unauthorized' do
      outsider = create(:user, account: account, role: :agent)

      update_state(user: outsider, pinned: true)

      expect(response).to have_http_status(:unauthorized)
    end
  end

  it 'pins the conversation for the agent' do
    update_state(pinned: true)

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('id' => conversation.display_id)
    expect(response.parsed_body['pinned_at']).to be_a(Integer)
    expect(response.parsed_body['archived_at']).to be_nil
    expect(ConversationUserState.find_by(user: agent, conversation: conversation).pinned_at).to be_present
  end

  it 'keeps the original pin time when pinned again' do
    update_state(pinned: true)
    first_pin = ConversationUserState.find_by(user: agent, conversation: conversation).pinned_at

    travel_to(1.hour.from_now) { update_state(pinned: true) }

    expect(ConversationUserState.find_by(user: agent, conversation: conversation).pinned_at).to eq(first_pin)
  end

  it 'archives the conversation for the agent' do
    update_state(archived: true)

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['archived_at']).to be_a(Integer)
    expect(ConversationUserState.find_by(user: agent, conversation: conversation).archived?).to be(true)
  end

  it 'unpins and unarchives, removing the row when nothing is left' do
    update_state(pinned: true, archived: true)
    update_state(pinned: false)
    expect(ConversationUserState.find_by(user: agent, conversation: conversation)).to be_present

    update_state(archived: false)

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('pinned_at' => nil, 'archived_at' => nil)
    expect(ConversationUserState.find_by(user: agent, conversation: conversation)).to be_nil
  end

  it 'only changes the key that was sent' do
    update_state(pinned: true)
    update_state(archived: true)

    expect(response.parsed_body['pinned_at']).to be_a(Integer)
  end

  it 'does not affect other agents' do
    update_state(pinned: true, archived: true)

    expect(ConversationUserState.where(user: colleague, conversation: conversation)).to be_empty
  end

  it 'refuses to pin more conversations than the limit' do
    ConversationUserState::MAX_PINNED.times do
      ConversationUserState.create!(user: agent, conversation: create(:conversation, inbox: inbox, account: account), pinned_at: Time.current)
    end

    update_state(pinned: true)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['error']).to include(ConversationUserState::MAX_PINNED.to_s)
    expect(ConversationUserState.where(user: agent, conversation: conversation)).to be_empty
  end

  describe 'conversation list' do
    def listed(user)
      get "/api/v1/accounts/#{account.id}/conversations", params: { status: 'open', assignee_type: 'all' },
                                                          headers: user.create_new_auth_token, as: :json
      response.parsed_body.dig('data', 'payload').index_by { |item| item['id'] }
    end

    it 'returns the pinned and archived time of the requesting agent only' do
      other_conversation = create(:conversation, inbox: inbox, account: account)
      update_state(pinned: true)

      mine = listed(agent)
      theirs = listed(colleague)

      expect(mine[conversation.display_id]['pinned_at']).to be_a(Integer)
      expect(mine[other_conversation.display_id]['pinned_at']).to be_nil
      expect(theirs[conversation.display_id]['pinned_at']).to be_nil
    end

    it 'lists pinned conversations first and hides archived ones' do
      older = create(:conversation, inbox: inbox, account: account, last_activity_at: 3.days.ago)
      newest = create(:conversation, inbox: inbox, account: account, last_activity_at: 1.minute.ago)
      update_state(target: older, pinned: true)
      update_state(target: newest, archived: true)

      get "/api/v1/accounts/#{account.id}/conversations", params: { status: 'open', assignee_type: 'all' },
                                                          headers: agent.create_new_auth_token, as: :json
      ids = response.parsed_body.dig('data', 'payload').pluck('id')

      expect(ids.first).to eq(older.display_id)
      expect(ids).not_to include(newest.display_id)
    end
  end
end
