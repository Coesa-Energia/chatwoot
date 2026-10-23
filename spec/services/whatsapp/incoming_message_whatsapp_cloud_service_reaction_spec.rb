require 'rails_helper'

# Inbound reactions annotate the reacted message instead of creating a message.
describe Whatsapp::IncomingMessageWhatsappCloudService do
  let!(:whatsapp_channel) { create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false) }
  let(:inbox) { whatsapp_channel.inbox }
  let(:sender_number) { '5511999990001' }
  let(:contact_inbox) { create(:contact_inbox, inbox: inbox, source_id: sender_number) }
  let(:conversation) { create(:conversation, inbox: inbox, contact_inbox: contact_inbox, contact: contact_inbox.contact) }
  let!(:target) do
    create(:message, conversation: conversation, inbox: inbox, account: conversation.account,
                     source_id: 'wamid.TARGET', message_type: :outgoing)
  end

  def reaction_params(emoji:, message_id: 'wamid.TARGET')
    {
      phone_number: whatsapp_channel.phone_number,
      object: 'whatsapp_business_account',
      entry: [{ changes: [{ value: {
        contacts: [{ profile: { name: 'Ana' }, wa_id: sender_number }],
        messages: [{ from: sender_number, id: "wamid.R#{SecureRandom.hex(4)}", timestamp: '1664799904', type: 'reaction',
                     reaction: { message_id: message_id, emoji: emoji }.compact }]
      } }] }]
    }.with_indifferent_access
  end

  after { Redis::Alfred.scan_each(match: 'MESSAGE_SOURCE_KEY::*') { |key| Redis::Alfred.delete(key) } }

  it 'stores the customer reaction on the reacted message' do
    described_class.new(inbox: inbox, params: reaction_params(emoji: '👍')).perform

    expect(target.reload.content_attributes['reactions']).to eq('contact' => '👍')
  end

  it 'replaces the customer reaction when they change it' do
    described_class.new(inbox: inbox, params: reaction_params(emoji: '👍')).perform
    described_class.new(inbox: inbox, params: reaction_params(emoji: '❤️')).perform

    expect(target.reload.content_attributes['reactions']).to eq('contact' => '❤️')
  end

  it 'removes the reaction when the emoji is empty' do
    described_class.new(inbox: inbox, params: reaction_params(emoji: '👍')).perform
    described_class.new(inbox: inbox, params: reaction_params(emoji: '')).perform

    expect(target.reload.content_attributes).not_to have_key('reactions')
  end

  it 'removes the reaction when the emoji is missing' do
    described_class.new(inbox: inbox, params: reaction_params(emoji: '👍')).perform
    described_class.new(inbox: inbox, params: reaction_params(emoji: nil)).perform

    expect(target.reload.content_attributes).not_to have_key('reactions')
  end

  it 'keeps the business reaction when the customer reacts' do
    Whatsapp::MessageReactions.new(message: target).set('business', '🙏')

    described_class.new(inbox: inbox, params: reaction_params(emoji: '👍')).perform

    expect(target.reload.content_attributes['reactions']).to eq('business' => '🙏', 'contact' => '👍')
  end

  it 'does not create messages, contacts or conversations' do
    expect do
      described_class.new(inbox: inbox, params: reaction_params(emoji: '👍')).perform
    end.not_to(change { [Message.count, Contact.count, Conversation.count] })
  end

  it 'ignores a reaction to a message it does not know' do
    expect do
      described_class.new(inbox: inbox, params: reaction_params(emoji: '👍', message_id: 'wamid.UNKNOWN')).perform
    end.not_to(change { [Message.count, Conversation.count] })
    expect(target.reload.content_attributes).not_to have_key('reactions')
  end

  it 'only looks for the reacted message inside the same inbox' do
    other_inbox = create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false).inbox

    described_class.new(inbox: other_inbox, params: reaction_params(emoji: '👍')).perform

    expect(target.reload.content_attributes).not_to have_key('reactions')
  end

  it 'broadcasts the message update so open dashboards refresh' do
    allow(Rails.configuration.dispatcher).to receive(:dispatch)

    described_class.new(inbox: inbox, params: reaction_params(emoji: '👍')).perform

    expect(Rails.configuration.dispatcher).to have_received(:dispatch).with(Events::Types::MESSAGE_UPDATED, anything, hash_including(message: target))
  end
end
