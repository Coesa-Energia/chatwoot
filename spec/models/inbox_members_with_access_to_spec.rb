require 'rails_helper'

RSpec.describe Inbox, '#members_with_access_to' do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:supervisor) { create(:user, account: account, role: :agent) }
  let(:assignee) { create(:user, account: account, role: :agent) }
  let(:participant) { create(:user, account: account, role: :agent) }
  let(:bystander) { create(:user, account: account, role: :agent) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: assignee) }

  before do
    create(:inbox_member, inbox: inbox, user: supervisor, see_all_conversations: true)
    inbox.add_members([assignee.id, participant.id, bystander.id])
    create(:conversation_participant, conversation: conversation, user: participant, account: account)
  end

  it 'new members only see their own conversations by default' do
    expect(InboxMember.find_by(inbox: inbox, user: bystander).see_all_conversations).to be(false)
  end

  describe '#members_with_access_to' do
    it 'returns the members that see everything, the assignee and the participants' do
      expect(inbox.members_with_access_to(conversation)).to contain_exactly(supervisor, assignee, participant)
    end

    it 'handles unassigned conversations' do
      conversation.update!(assignee: nil)

      expect(inbox.members_with_access_to(conversation)).to contain_exactly(supervisor, participant)
    end
  end

  describe '#update_conversation_access' do
    it 'grants the listed members and restricts the others' do
      inbox.update_conversation_access([bystander.id.to_s])

      expect(inbox.inbox_members.where(see_all_conversations: true).pluck(:user_id)).to eq([bystander.id])
    end
  end
end
