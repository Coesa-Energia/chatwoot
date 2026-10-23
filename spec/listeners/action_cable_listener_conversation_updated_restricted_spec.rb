require 'rails_helper'

describe ActionCableListener, '#conversation_updated' do
  let(:listener) { described_class.instance }
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let!(:admin) { create(:user, account: account, role: :administrator) }
  let(:assignee) { create(:user, account: account, role: :agent) }
  let(:supervisor) { create(:user, account: account, role: :agent) }
  let(:bystander) { create(:user, account: account, role: :agent) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: assignee) }

  before do
    inbox.add_members([assignee.id, supervisor.id, bystander.id])
    inbox.update_conversation_access([supervisor.id])
    Current.user = nil
    Current.account = nil
  end

  def tokens_for(event_name)
    broadcast = nil
    allow(ActionCableBroadcastJob).to receive(:perform_later) { |tokens, name, _data| broadcast = tokens if name == event_name }
    yield
    broadcast
  end

  it 'only tells the assignee, members that see everything and admins about conversation updates' do
    event = Events::Base.new(:'conversation.updated', Time.zone.now, conversation: conversation)

    tokens = tokens_for('conversation.updated') { listener.conversation_updated(event) }

    expect(tokens).to include(assignee.pubsub_token, supervisor.pubsub_token, admin.pubsub_token)
    expect(tokens).not_to include(bystander.pubsub_token)
  end

  it 'does not announce new messages to restricted members who are not involved' do
    message = create(:message, conversation: conversation, account: account, inbox: inbox)
    event = Events::Base.new(:'message.created', Time.zone.now, message: message)

    tokens = tokens_for('message.created') { listener.message_created(event) }

    expect(tokens).not_to include(bystander.pubsub_token)
    expect(tokens).to include(assignee.pubsub_token)
  end

  it 'includes participants' do
    create(:conversation_participant, conversation: conversation, user: bystander, account: account)
    event = Events::Base.new(:'conversation.updated', Time.zone.now, conversation: conversation)

    tokens = tokens_for('conversation.updated') { listener.conversation_updated(event) }

    expect(tokens).to include(bystander.pubsub_token)
  end
end
