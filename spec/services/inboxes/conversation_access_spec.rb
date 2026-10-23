require 'rails_helper'

RSpec.describe Inboxes::ConversationAccess do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:other_inbox) { create(:inbox, account: account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:colleague) { create(:user, account: account, role: :agent) }
  let!(:own) { create(:conversation, account: account, inbox: inbox, assignee: agent) }
  let!(:followed) { create(:conversation, account: account, inbox: inbox, assignee: colleague) }
  let!(:unassigned) { create(:conversation, account: account, inbox: inbox, assignee: nil) }
  let!(:theirs) { create(:conversation, account: account, inbox: inbox, assignee: colleague) }
  let!(:in_open_inbox) { create(:conversation, account: account, inbox: other_inbox, assignee: colleague) }

  before do
    create(:inbox_member, inbox: inbox, user: agent, see_all_conversations: false)
    create(:inbox_member, inbox: other_inbox, user: agent, see_all_conversations: true)
    create(:conversation_participant, conversation: followed, user: agent, account: account)
  end

  describe '.restricted_inbox_ids' do
    it 'lists only the inboxes where the member is restricted' do
      expect(described_class.restricted_inbox_ids(user: agent, account: account)).to eq([inbox.id])
    end
  end

  describe '.apply' do
    it 'keeps own and followed conversations in restricted inboxes and everything in open inboxes' do
      visible = described_class.apply(account.conversations, user: agent, account: account)

      expect(visible).to contain_exactly(own, followed, in_open_inbox)
    end

    it 'does not restrict anything for a member that sees all conversations' do
      InboxMember.find_by(inbox: inbox, user: agent).update!(see_all_conversations: true)

      expect(described_class.apply(account.conversations, user: agent,
                                                          account: account)).to contain_exactly(own, followed, unassigned, theirs, in_open_inbox)
    end
  end

  describe Conversations::PermissionFilterService do
    it 'applies the restriction for agents' do
      result = described_class.new(account.conversations, agent, account).perform

      expect(result).to contain_exactly(own, followed, in_open_inbox)
    end

    it 'applies the restriction when the planner hint is used' do
      result = described_class.new(account.conversations, agent, account, plan_hint_selective_filter: true).perform

      expect(result).to contain_exactly(own, followed, in_open_inbox)
    end

    it 'never restricts administrators' do
      admin = create(:user, account: account, role: :administrator)

      expect(described_class.new(account.conversations, admin, account).perform).to include(unassigned, theirs)
    end
  end
end
