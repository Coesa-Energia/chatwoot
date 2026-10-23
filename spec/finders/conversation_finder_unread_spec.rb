require 'rails_helper'

# "Unread" = incoming messages created after the agent last saw the conversation
# (every incoming message when the agent never opened it), like Conversation#unread_messages.
describe ConversationFinder do
  let!(:account) { create(:account) }
  let!(:agent) { create(:user, account: account) }
  let!(:inbox) { create(:inbox, account: account, enable_auto_assignment: false) }

  let!(:never_opened) { create(:conversation, account: account, inbox: inbox, agent_last_seen_at: nil) }
  let!(:read_up_to_date) { create(:conversation, account: account, inbox: inbox, agent_last_seen_at: 1.hour.ago) }
  let!(:new_message_after_seen) { create(:conversation, account: account, inbox: inbox, agent_last_seen_at: 2.hours.ago) }
  let!(:only_outgoing_after_seen) { create(:conversation, account: account, inbox: inbox, agent_last_seen_at: 2.hours.ago) }
  let!(:no_messages) { create(:conversation, account: account, inbox: inbox, agent_last_seen_at: nil) }

  before do
    create(:inbox_member, user: agent, inbox: inbox)
    create(:message, conversation: never_opened, account: account, inbox: inbox, message_type: :incoming, created_at: 3.hours.ago)
    create(:message, conversation: read_up_to_date, account: account, inbox: inbox, message_type: :incoming, created_at: 3.hours.ago)
    create(:message, conversation: new_message_after_seen, account: account, inbox: inbox, message_type: :incoming, created_at: 30.minutes.ago)
    create(:message, conversation: only_outgoing_after_seen, account: account, inbox: inbox, message_type: :outgoing, created_at: 30.minutes.ago)
    Current.account = account
  end

  def ids_for(params)
    described_class.new(agent, params).perform[:conversations].map(&:id)
  end

  it 'returns only conversations with unread incoming messages when unread is true' do
    ids = ids_for(status: 'open', assignee_type: 'all', unread: 'true')

    expect(ids).to contain_exactly(never_opened.id, new_message_after_seen.id)
  end

  it 'returns every conversation when unread is not set' do
    ids = ids_for(status: 'open', assignee_type: 'all')

    expect(ids).to include(never_opened.id, read_up_to_date.id, new_message_after_seen.id, only_outgoing_after_seen.id, no_messages.id)
  end

  it 'ignores unread=false' do
    expect(ids_for(status: 'open', assignee_type: 'all', unread: 'false').size).to eq(5)
  end

  it 'combines with the other filters' do
    new_message_after_seen.update!(status: :resolved)

    expect(ids_for(status: 'open', assignee_type: 'all', unread: 'true')).to contain_exactly(never_opened.id)
  end

  it 'matches the conversation unread count used by the UI' do
    flagged = ids_for(status: 'all', assignee_type: 'all', unread: 'true')
    with_unread = Conversation.where(account: account).select { |conversation| conversation.unread_incoming_messages.any? }.map(&:id)

    expect(flagged).to match_array(with_unread)
  end

  it 'applies to the meta counts as well' do
    meta = described_class.new(agent, { status: 'open', assignee_type: 'all', unread: 'true' }).perform_meta_only

    expect(meta[:count][:all_count]).to eq(2)
  end
end
