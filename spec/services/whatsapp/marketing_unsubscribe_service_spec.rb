require 'rails_helper'

describe Whatsapp::MarketingUnsubscribeService do
  before do
    stub_request(:post, 'https://waba.360dialog.io/v1/configs/webhook')
  end

  after do
    Redis::Alfred.scan_each(match: 'MESSAGE_SOURCE_KEY::*') { |key| Redis::Alfred.delete(key) }
  end

  let!(:whatsapp_channel) { create(:channel_whatsapp, sync_templates: false) }
  let(:wa_id) { '2423423243' }

  def incoming_params(message)
    {
      'contacts' => [{ 'profile' => { 'name' => 'Cliente' }, 'wa_id' => wa_id }],
      'messages' => [message.merge('from' => wa_id, 'id' => SecureRandom.hex(8), 'timestamp' => '1633034394')]
    }.with_indifferent_access
  end

  describe 'when the customer clicks the unsubscribe button' do
    let(:params) do
      incoming_params('type' => 'button', 'button' => { 'text' => described_class::BUTTON_TEXT, 'payload' => described_class::BUTTON_TEXT })
    end

    it 'labels the contact, sends the notice and resolves the conversation' do
      Whatsapp::IncomingMessageService.new(inbox: whatsapp_channel.inbox, params: params).perform

      conversation = whatsapp_channel.inbox.conversations.last
      contact = conversation.contact
      expect(contact.label_list).to include(described_class::LABEL)
      expect(contact.custom_attributes[described_class::DATE_ATTRIBUTE]).to be_present
      expect(conversation.reload).to be_resolved
      expect(conversation.label_list).to include(described_class::LABEL)
      expect(conversation.messages.outgoing.last.content).to eq(described_class::CONFIRMATION)
      expect(whatsapp_channel.account.labels.find_by(title: described_class::LABEL)).to be_present
    end
  end

  describe 'when the customer types the same text' do
    let(:params) { incoming_params('type' => 'text', 'text' => { 'body' => described_class::BUTTON_TEXT }) }

    it 'does not unsubscribe' do
      Whatsapp::IncomingMessageService.new(inbox: whatsapp_channel.inbox, params: params).perform

      conversation = whatsapp_channel.inbox.conversations.last
      expect(conversation.contact.label_list).not_to include(described_class::LABEL)
      expect(conversation.reload).to be_open
    end
  end

  describe 'when the customer clicks another button' do
    let(:params) { incoming_params('type' => 'button', 'button' => { 'text' => 'Quero saber mais' }) }

    it 'does not unsubscribe' do
      Whatsapp::IncomingMessageService.new(inbox: whatsapp_channel.inbox, params: params).perform

      expect(whatsapp_channel.inbox.conversations.last.contact.label_list).not_to include(described_class::LABEL)
    end
  end

  describe 'blocking templates for unsubscribed contacts' do
    let(:marketing_template) do
      { 'name' => 'vendas_remarketing', 'status' => 'approved', 'category' => 'MARKETING', 'language' => 'pt_BR',
        'components' => [{ 'type' => 'BODY', 'text' => 'Oferta' }] }
    end
    let!(:contact_inbox) { create(:contact_inbox, inbox: whatsapp_channel.inbox, source_id: '123456789') }
    let!(:conversation) { create(:conversation, contact_inbox: contact_inbox, inbox: whatsapp_channel.inbox) }

    before do
      whatsapp_channel.update!(message_templates: whatsapp_channel.message_templates + [marketing_template])
      contact_inbox.contact.add_labels([described_class::LABEL])
    end

    it 'fails a MARKETING template without calling WhatsApp' do
      message = create(:message, message_type: :outgoing, content: 'Oferta', conversation: conversation, account: conversation.account,
                                 additional_attributes: { template_params: { name: 'vendas_remarketing', language: 'pt_BR' } })

      Whatsapp::SendOnWhatsappService.new(message: message).perform

      expect(message.reload).to be_failed
      expect(message.external_error).to eq(I18n.t('errors.whatsapp.marketing_unsubscribed'))
      expect(a_request(:post, 'https://waba.360dialog.io/v1/messages')).not_to have_been_made
    end

    it 'still sends templates of other categories' do
      stub_request(:post, 'https://waba.360dialog.io/v1/messages')
        .to_return(status: 200, body: { 'messages' => [{ 'id' => '123456789' }] }.to_json, headers: { 'content-type' => 'application/json' })
      message = create(:message, message_type: :outgoing, content: 'Seu pacote', conversation: conversation, account: conversation.account,
                                 additional_attributes: { template_params: { name: 'sample_shipping_confirmation', language: 'en_US',
                                                                             processed_params: { 'body' => { '1' => '3' } } } })

      Whatsapp::SendOnWhatsappService.new(message: message).perform

      expect(message.reload.source_id).to eq('123456789')
    end
  end
end
