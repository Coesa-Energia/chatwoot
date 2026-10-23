require 'rails_helper'

RSpec.describe ConversationUserState do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account) }
  let(:inbox) { create(:inbox, account: account) }

  def new_conversation
    create(:conversation, account: account, inbox: inbox)
  end

  it 'takes the account from the conversation' do
    conversation = new_conversation

    state = described_class.create!(user: agent, conversation: conversation, pinned_at: Time.current)

    expect(state.account_id).to eq(account.id)
  end

  it 'allows one state per agent and conversation' do
    conversation = new_conversation
    described_class.create!(user: agent, conversation: conversation, pinned_at: Time.current)

    duplicate = described_class.new(user: agent, conversation: conversation, archived_at: Time.current)

    expect(duplicate).not_to be_valid
  end

  describe 'pinned limit' do
    before do
      described_class::MAX_PINNED.times do
        described_class.create!(user: agent, conversation: new_conversation, pinned_at: Time.current)
      end
    end

    it 'does not allow pinning more than the limit' do
      state = described_class.new(user: agent, conversation: new_conversation, pinned_at: Time.current)

      expect(state).not_to be_valid
      expect(state.errors.full_messages.to_sentence).to include(described_class::MAX_PINNED.to_s)
    end

    it 'still allows archiving more conversations' do
      state = described_class.new(user: agent, conversation: new_conversation, archived_at: Time.current)

      expect(state).to be_valid
    end

    it 'does not count another agent\'s pins' do
      other = create(:user, account: account)

      expect(described_class.new(user: other, conversation: new_conversation, pinned_at: Time.current)).to be_valid
    end

    it 'lets an already pinned conversation be saved again' do
      existing = described_class.where(user: agent).where.not(pinned_at: nil).first

      expect(existing.update(archived_at: Time.current)).to be(true)
    end
  end

  describe '#archived?' do
    let(:conversation) { new_conversation }

    it 'is archived once archived_at is set' do
      conversation.update_columns(last_activity_at: 2.hours.ago) # rubocop:disable Rails/SkipsModelValidations
      state = described_class.create!(user: agent, conversation: conversation, archived_at: 1.hour.ago)

      expect(state.archived?).to be(true)
    end

    it 'stays archived after new activity in the conversation' do
      state = described_class.create!(user: agent, conversation: conversation, archived_at: 2.hours.ago)
      conversation.update_columns(last_activity_at: 1.minute.ago) # rubocop:disable Rails/SkipsModelValidations

      expect(state.archived?).to be(true)
    end

    it 'is not archived without archived_at' do
      state = described_class.create!(user: agent, conversation: conversation, pinned_at: Time.current)

      expect(state.archived?).to be(false)
    end
  end
end
