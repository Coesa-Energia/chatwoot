require 'rails_helper'

# Search inside a single conversation ("search in chat").
RSpec.describe 'Conversation messages search API', type: :request do
  let!(:account) { create(:account) }
  let!(:inbox) { create(:inbox, account: account) }
  let!(:conversation) { create(:conversation, inbox: inbox, account: account) }
  let(:agent) { create(:user, account: account, role: :agent) }

  def make_message(content, **attrs)
    create(:message, conversation: conversation, account: account, inbox: inbox, content: content, **attrs)
  end

  def search(query, user: agent, target: conversation)
    get "/api/v1/accounts/#{account.id}/conversations/#{target.display_id}/messages/search",
        params: { q: query }, headers: user.create_new_auth_token, as: :json
    response.parsed_body['payload']
  end

  context 'when unauthenticated' do
    it 'returns unauthorized' do
      get "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/messages/search", params: { q: 'oi' }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  context 'when the agent has no access to the inbox' do
    it 'returns unauthorized' do
      search('orçamento')

      expect(response).to have_http_status(:unauthorized)
    end
  end

  context 'when the agent has access to the inbox' do
    before { create(:inbox_member, inbox: inbox, user: agent) }

    it 'finds matching messages, newest first' do
      old = make_message('quero um orçamento solar', created_at: 3.days.ago)
      recent = make_message('segue o ORÇAMENTO revisado', created_at: 1.hour.ago)
      make_message('bom dia')

      expect(search('orçamento').pluck('id')).to eq([recent.id, old.id])
    end

    it 'returns the fields the client needs to show and jump to a result' do
      message = make_message('segunda via da conta', message_type: :incoming)

      result = search('segunda via').first

      expect(result).to include('id' => message.id, 'content' => 'segunda via da conta', 'message_type' => 'incoming', 'private' => false)
      expect(result['created_at']).to be_a(Integer)
    end

    it 'includes private notes' do
      note = make_message('cliente pediu desconto', private: true, message_type: :outgoing)

      expect(search('desconto').pluck('id')).to eq([note.id])
    end

    it 'ignores activity messages' do
      make_message('Conversation was assigned to Maria', message_type: :activity)

      expect(search('assigned')).to be_empty
    end

    it 'only searches the given conversation' do
      other = create(:conversation, inbox: inbox, account: account)
      create(:message, conversation: other, account: account, inbox: inbox, content: 'orçamento do outro cliente')
      mine = make_message('meu orçamento')

      expect(search('orçamento').pluck('id')).to eq([mine.id])
    end

    it 'treats % and _ as plain text instead of wildcards' do
      percent = make_message('desconto de 10% hoje')
      make_message('desconto de 10 hoje')

      expect(search('10%').pluck('id')).to eq([percent.id])
      expect(search('_')).to be_empty
    end

    it 'returns nothing for queries shorter than two characters' do
      make_message('a conta chegou')

      expect(search('a')).to be_empty
      expect(search('  ')).to be_empty
    end

    it 'caps the number of results' do
      stub_const('Api::V1::Accounts::Conversations::MessagesController::SEARCH_LIMIT', 3)
      5.times { |i| make_message("pedido #{i}") }

      expect(search('pedido').size).to eq(3)
    end
  end
end
