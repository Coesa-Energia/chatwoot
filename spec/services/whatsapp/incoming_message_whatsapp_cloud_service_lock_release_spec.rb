require 'rails_helper'

# The dedup lock is taken before the message is created. If creation fails, the lock must
# be released so the job retry processes the message instead of dropping it as a duplicate.
describe Whatsapp::IncomingMessageWhatsappCloudService do
  let!(:whatsapp_channel) { create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false) }
  let(:sender_number) { '5511999990001' }
  let(:wamid) { "wamid.lock_release_#{SecureRandom.hex(6)}" }
  let(:params) do
    {
      phone_number: whatsapp_channel.phone_number,
      object: 'whatsapp_business_account',
      entry: [{ changes: [{ value: {
        contacts: [{ profile: { name: 'Ana' }, wa_id: sender_number }],
        messages: [{ from: sender_number, id: wamid, text: { body: 'oi' }, timestamp: '1664799904', type: 'text' }]
      } }] }]
    }.with_indifferent_access
  end

  after do
    Redis::Alfred.scan_each(match: 'MESSAGE_SOURCE_KEY::*') { |key| Redis::Alfred.delete(key) }
  end

  it 'releases the dedup lock when message creation fails, so a retry creates the message' do
    failing = described_class.new(inbox: whatsapp_channel.inbox, params: params)
    allow(failing).to receive(:create_messages).and_raise(StandardError, 'boom')

    expect { failing.perform }.to raise_error(StandardError, 'boom')
    expect(whatsapp_channel.inbox.messages.where(source_id: wamid)).to be_empty

    described_class.new(inbox: whatsapp_channel.inbox, params: params).perform

    expect(whatsapp_channel.inbox.messages.find_by(source_id: wamid)&.content).to eq('oi')
  end

  it 'still ignores a true duplicate delivery of a message that was already created' do
    described_class.new(inbox: whatsapp_channel.inbox, params: params).perform
    described_class.new(inbox: whatsapp_channel.inbox, params: params).perform

    expect(whatsapp_channel.inbox.messages.where(source_id: wamid).count).to eq(1)
  end
end
