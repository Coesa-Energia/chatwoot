require 'rails_helper'

# Phone numbers typed in any format, the unlimited default search window, and the gin tsquery sanitising.
describe SearchService do
  subject(:search) do
    described_class.new(current_user: user, current_account: account, params: params, search_type: search_type)
  end

  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:params) { { q: query } }
  let(:search_type) { 'Contact' }
  let(:query) { '' }

  before do
    create(:inbox_member, user: user, inbox: inbox)
    account.account_users.find_by(user: user).update!(role: 'administrator')
    Current.account = account
  end

  describe 'phone number search' do
    let!(:ana) { create(:contact, name: 'Ana', phone_number: '+5511999990001', account: account) }
    let!(:landline) { create(:contact, name: 'Fixo', phone_number: '+551133334444', account: account) }
    let!(:other) { create(:contact, name: 'Outro', phone_number: '+5521988887777', account: account) }

    def contact_ids(text)
      described_class.new(current_user: user, current_account: account, params: { q: text }, search_type: 'Contact')
                     .perform[:contacts].map(&:id)
    end

    ['(11) 99999-0001', '11999990001', '11 99999 0001', '+55 11 99999-0001', '5511999990001', '99999-0001'].each do |typed|
      it "finds the contact when the number is typed as #{typed}" do
        expect(contact_ids(typed)).to contain_exactly(ana.id)
      end
    end

    it 'finds a number stored with the ninth digit when typed without it' do
      expect(contact_ids('11 9999-0001')).to contain_exactly(ana.id)
    end

    it 'finds a number stored without the ninth digit when typed with it' do
      old_format = create(:contact, name: 'Antigo', phone_number: '+551188887777', account: account)

      expect(contact_ids('(11) 98888-7777')).to contain_exactly(old_format.id)
    end

    it 'finds landlines typed with formatting' do
      expect(contact_ids('(11) 3333-4444')).to contain_exactly(landline.id)
    end

    it 'still finds by name' do
      expect(contact_ids('Ana')).to contain_exactly(ana.id)
    end

    it 'does not turn short digit strings into broad phone matches' do
      expect(contact_ids('99')).not_to include(other.id)
    end

    it 'also matches the contact phone when searching conversations' do
      conversation = create(:conversation, contact: ana, inbox: inbox, account: account)
      result = described_class.new(current_user: user, current_account: account, params: { q: '(11) 99999-0001' },
                                   search_type: 'Conversation').perform[:conversations]

      expect(result.map(&:id)).to include(conversation.id)
    end
  end

  describe 'message search window' do
    let(:search_type) { 'Message' }
    let(:query) { 'orçamento' }
    let(:contact) { create(:contact, account: account) }
    let(:conversation) { create(:conversation, contact: contact, inbox: inbox, account: account) }
    let!(:old_message) do
      create(:message, content: 'pedido de orçamento antigo', conversation: conversation, account: account, inbox: inbox, created_at: 2.years.ago)
    end
    let!(:recent_message) do
      create(:message, content: 'pedido de orçamento novo', conversation: conversation, account: account, inbox: inbox, created_at: 1.day.ago)
    end

    it 'searches the whole history by default' do
      ids = search.perform[:messages].map(&:id)

      expect(ids).to include(old_message.id, recent_message.id)
    end

    it 'caps the history when MESSAGE_SEARCH_WINDOW_DAYS is set' do
      with_modified_env(MESSAGE_SEARCH_WINDOW_DAYS: '90') do
        ids = described_class.new(current_user: user, current_account: account, params: params, search_type: 'Message')
                             .perform[:messages].map(&:id)

        expect(ids).to include(recent_message.id)
        expect(ids).not_to include(old_message.id)
      end
    end
  end

  describe 'gin message search with special characters' do
    let(:search_type) { 'Message' }
    let(:contact) { create(:contact, account: account) }
    let(:conversation) { create(:conversation, contact: contact, inbox: inbox, account: account) }
    let!(:message) { create(:message, content: 'preciso do boleto maio', conversation: conversation, account: account, inbox: inbox) }

    before { account.enable_features!('search_with_gin') }

    ["boleto d'ouro", 'boleto:maio', 'boleto & (maio', '!!!', "'"].each do |typed|
      it "does not raise for the query #{typed.inspect}" do
        result = described_class.new(current_user: user, current_account: account, params: { q: typed }, search_type: 'Message')

        expect { result.perform[:messages].to_a }.not_to raise_error
      end
    end

    it 'still matches a normal phrase' do
      result = described_class.new(current_user: user, current_account: account, params: { q: 'boleto maio' }, search_type: 'Message')

      expect(result.perform[:messages].map(&:id)).to include(message.id)
    end
  end
end
