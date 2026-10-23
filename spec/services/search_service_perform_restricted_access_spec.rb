require 'rails_helper'

RSpec.describe SearchService, '#perform' do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:colleague) { create(:user, account: account, role: :agent) }
  let(:contact) { create(:contact, account: account, name: 'Shared Customer') }
  let!(:own) { create(:conversation, account: account, inbox: inbox, assignee: agent, contact: contact) }
  let!(:theirs) { create(:conversation, account: account, inbox: inbox, assignee: colleague, contact: contact) }

  before do
    Current.account = account
    inbox.add_members([agent.id, colleague.id])
    create(:message, conversation: own, account: account, inbox: inbox, content: 'proposal for solar roof')
    create(:message, conversation: theirs, account: account, inbox: inbox, content: 'proposal for wind turbine')
  end

  def search(type, user: agent, query: 'proposal')
    described_class.new(current_user: user, current_account: account, params: { q: query }, search_type: type).perform
  end

  it 'finds only messages of conversations the agent may open' do
    contents = search('Message')[:messages].map(&:content)

    expect(contents).to eq(['proposal for solar roof'])
  end

  it 'finds only the agent\'s conversations' do
    expect(search('Conversation', query: 'Shared')[:conversations].map(&:display_id)).to eq([own.display_id])
  end

  it 'finds everything once the agent is released' do
    inbox.update_conversation_access([agent.id])

    expect(search('Message')[:messages].size).to eq(2)
    expect(search('Conversation', query: 'Shared')[:conversations].size).to eq(2)
  end

  it 'never restricts administrators' do
    admin = create(:user, account: account, role: :administrator)

    expect(search('Message', user: admin)[:messages].size).to eq(2)
  end
end
