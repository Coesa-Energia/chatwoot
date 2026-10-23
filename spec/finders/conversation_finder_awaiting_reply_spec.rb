require 'rails_helper'

# "Awaiting reply" = the customer wrote last and nobody answered yet (waiting_since is set).
describe ConversationFinder do
  let!(:account) { create(:account) }
  let!(:agent) { create(:user, account: account) }
  let!(:inbox) { create(:inbox, account: account, enable_auto_assignment: false) }

  let!(:waiting) { create(:conversation, account: account, inbox: inbox, waiting_since: 2.hours.ago) }
  let!(:answered) { create(:conversation, account: account, inbox: inbox) }
  let!(:resolved_waiting) { create(:conversation, account: account, inbox: inbox, status: :resolved, waiting_since: 1.hour.ago) }

  before do
    create(:inbox_member, user: agent, inbox: inbox)
    answered.update_column(:waiting_since, nil) # rubocop:disable Rails/SkipsModelValidations
    Current.account = account
  end

  def ids_for(params)
    described_class.new(agent, params).perform[:conversations].map(&:id)
  end

  it 'returns only conversations where the customer is waiting when awaiting_reply is true' do
    expect(ids_for(status: 'open', assignee_type: 'all', awaiting_reply: 'true')).to contain_exactly(waiting.id)
  end

  it 'returns every open conversation when awaiting_reply is not set' do
    expect(ids_for(status: 'open', assignee_type: 'all')).to contain_exactly(waiting.id, answered.id)
  end

  it 'ignores awaiting_reply=false' do
    expect(ids_for(status: 'open', assignee_type: 'all', awaiting_reply: 'false')).to contain_exactly(waiting.id, answered.id)
  end

  it 'combines with the status filter' do
    expect(ids_for(status: 'resolved', assignee_type: 'all', awaiting_reply: 'true')).to contain_exactly(resolved_waiting.id)
  end

  it 'combines with the unread filter' do
    create(:message, conversation: waiting, account: account, inbox: inbox, message_type: :incoming)
    waiting.update!(agent_last_seen_at: Time.current)

    expect(ids_for(status: 'open', assignee_type: 'all', awaiting_reply: 'true', unread: 'true')).to be_empty
  end

  it 'applies to the meta counts as well' do
    meta = described_class.new(agent, { status: 'open', assignee_type: 'all', awaiting_reply: 'true' }).perform_meta_only

    expect(meta[:count][:all_count]).to eq(1)
  end
end
