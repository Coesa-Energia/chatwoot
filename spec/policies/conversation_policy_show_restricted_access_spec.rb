require 'rails_helper'

RSpec.describe ConversationPolicy, '#show?', type: :policy do
  subject { described_class }

  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:colleague) { create(:user, account: account, role: :agent) }
  let(:context) { { user: agent, account: account, account_user: agent.account_users.find_by(account: account) } }
  let(:admin_context) do
    admin = create(:user, account: account, role: :administrator)
    { user: admin, account: account, account_user: admin.account_users.find_by(account: account) }
  end
  let(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: colleague) }
  let!(:membership) { create(:inbox_member, inbox: inbox, user: agent, see_all_conversations: false) }

  permissions :show? do
    it 'denies a restricted agent conversations that are not theirs' do
      expect(subject).not_to permit(context, conversation)
    end

    it 'denies a restricted agent unassigned conversations' do
      expect(subject).not_to permit(context, create(:conversation, account: account, inbox: inbox, assignee: nil))
    end

    it 'allows conversations assigned to the agent' do
      conversation.update!(assignee: agent)

      expect(subject).to permit(context, conversation)
    end

    it 'allows conversations where the agent is a participant' do
      create(:conversation_participant, conversation: conversation, user: agent, account: account)

      expect(subject).to permit(context, conversation)
    end

    it 'allows everything once the member may see all conversations' do
      membership.update!(see_all_conversations: true)

      expect(subject).to permit(context, conversation)
    end

    it 'never restricts administrators' do
      expect(subject).to permit(admin_context, conversation)
    end

    it 'does not grant access to agents outside the inbox' do
      membership.destroy!

      expect(subject).not_to permit(context, conversation)
    end
  end
end
