require 'rails_helper'

# Pinned conversations come first and archived ones are hidden, per agent.
describe ConversationFinder do
  let!(:account) { create(:account) }
  let!(:agent) { create(:user, account: account) }
  let!(:colleague) { create(:user, account: account) }
  let!(:inbox) { create(:inbox, account: account, enable_auto_assignment: false) }

  let!(:newest) { create(:conversation, account: account, inbox: inbox, last_activity_at: 1.minute.ago) }
  let!(:middle) { create(:conversation, account: account, inbox: inbox, last_activity_at: 1.hour.ago) }
  let!(:oldest) { create(:conversation, account: account, inbox: inbox, last_activity_at: 1.day.ago) }

  before do
    create(:inbox_member, user: agent, inbox: inbox)
    create(:inbox_member, user: colleague, inbox: inbox)
    Current.account = account
  end

  def ids_for(user: agent, **params)
    described_class.new(user, { status: 'open', assignee_type: 'all' }.merge(params)).perform[:conversations].map(&:id)
  end

  def pin(conversation, user: agent, at: Time.current)
    ConversationUserState.create!(user: user, conversation: conversation, pinned_at: at)
  end

  def archive(conversation, user: agent, at: Time.current)
    ConversationUserState.create!(user: user, conversation: conversation, archived_at: at)
  end

  describe 'pinned conversations' do
    it 'keeps the normal order when nothing is pinned' do
      expect(ids_for).to eq([newest.id, middle.id, oldest.id])
    end

    it 'lists pinned conversations first, newest pin first, then the rest by the chosen sort' do
      pin(oldest, at: 2.hours.ago)
      pin(middle, at: 1.hour.ago)

      expect(ids_for).to eq([middle.id, oldest.id, newest.id])
    end

    it 'keeps pinned conversations first with another sort order' do
      pin(newest)

      expect(ids_for(sort_by: 'last_activity_at_asc')).to eq([newest.id, oldest.id, middle.id])
    end

    it 'does not show another agent\'s pins' do
      pin(oldest, user: colleague)

      expect(ids_for).to eq([newest.id, middle.id, oldest.id])
      expect(ids_for(user: colleague).first).to eq(oldest.id)
    end

    it 'paginates with pinned conversations on the first page' do
      pin(oldest)
      stub_const('ENV', ENV.to_hash.merge('CONVERSATION_RESULTS_PER_PAGE' => '1'))

      expect(ids_for(page: 1)).to eq([oldest.id])
      expect(ids_for(page: 2)).to eq([newest.id])
    end

    it 'keeps pinned conversations that match the other filters' do
      pin(oldest)
      oldest.update!(status: :resolved)

      expect(ids_for).to eq([newest.id, middle.id])
      expect(ids_for(status: 'resolved')).to eq([oldest.id])
    end
  end

  describe 'archived conversations' do
    it 'hides archived conversations from the default list' do
      archive(middle, at: Time.current)

      expect(ids_for).to eq([newest.id, oldest.id])
    end

    it 'shows only the archived conversations when archived is true' do
      archive(middle, at: Time.current)

      expect(ids_for(archived: 'true')).to eq([middle.id])
    end

    it 'keeps an archived conversation archived when something new happens in it' do
      archive(middle, at: 30.minutes.ago)
      middle.update_columns(last_activity_at: 1.minute.ago) # rubocop:disable Rails/SkipsModelValidations

      expect(ids_for).not_to include(middle.id)
      expect(ids_for(archived: 'true')).to eq([middle.id])
    end

    it 'does not hide a conversation another agent archived' do
      archive(middle, user: colleague)

      expect(ids_for).to include(middle.id)
      expect(ids_for(user: colleague)).not_to include(middle.id)
    end

    it 'excludes archived conversations from the counts' do
      archive(middle)

      meta = described_class.new(agent, { status: 'open', assignee_type: 'all' }).perform_meta_only

      expect(meta[:count][:all_count]).to eq(2)
    end

    it 'can be a pinned conversation too (pinned and archived at the same time)' do
      ConversationUserState.create!(user: agent, conversation: middle, pinned_at: Time.current, archived_at: Time.current)

      expect(ids_for).not_to include(middle.id)
      expect(ids_for(archived: 'true')).to eq([middle.id])
    end
  end

  it 'combines with the unread and awaiting reply filters' do
    archive(middle)
    create(:message, conversation: newest, account: account, inbox: inbox, message_type: :incoming)

    expect(ids_for(unread: 'true')).to eq([newest.id])
  end
end
