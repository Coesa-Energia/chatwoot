require 'rails_helper'

# The blue ticks: once an agent has seen the conversation, the customer's latest message is marked as read.
describe Whatsapp::ReadReceiptService do
  let(:channel) { create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false) }
  let(:inbox) { channel.inbox }
  let(:conversation) { create(:conversation, inbox: inbox, account: inbox.account, agent_last_seen_at: Time.current) }
  let(:meta_url) { %r{graph\.facebook\.com/v22.0/.+/messages} }
  let(:meta_ok) { { status: 200, body: { success: true }.to_json, headers: { 'Content-Type' => 'application/json' } } }

  def incoming(source_id, created_at: 5.minutes.ago)
    create(:message, conversation: conversation, inbox: inbox, account: inbox.account,
                     message_type: :incoming, source_id: source_id, created_at: created_at)
  end

  def perform
    described_class.new(conversation: conversation.reload).perform
  end

  it 'marks the latest customer message as read once the agent has seen it' do
    incoming('wamid.OLD', created_at: 2.hours.ago)
    incoming('wamid.NEW')
    stub = stub_request(:post, meta_url).with(body: { messaging_product: 'whatsapp', status: 'read', message_id: 'wamid.NEW' }).to_return(meta_ok)

    perform

    expect(stub).to have_been_requested.once
  end

  it 'does not send it twice for the same message' do
    incoming('wamid.NEW')
    stub = stub_request(:post, meta_url).to_return(meta_ok)

    perform
    perform

    expect(stub).to have_been_requested.once
  end

  it 'sends a new one when a newer customer message arrives and is seen' do
    incoming('wamid.ONE')
    stub = stub_request(:post, meta_url).to_return(meta_ok)
    perform

    incoming('wamid.TWO', created_at: 1.minute.ago)
    conversation.update_columns(agent_last_seen_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    perform

    expect(stub).to have_been_requested.twice
    expect(a_request(:post, meta_url).with(body: hash_including(message_id: 'wamid.TWO'))).to have_been_made.once
  end

  it 'waits until the agent has actually seen the message' do
    incoming('wamid.NEW')
    conversation.update_columns(agent_last_seen_at: 1.hour.ago) # rubocop:disable Rails/SkipsModelValidations
    stub = stub_request(:post, meta_url).to_return(meta_ok)

    perform

    expect(stub).not_to have_been_requested
  end

  it 'does nothing when the agent never saw the conversation' do
    incoming('wamid.NEW')
    conversation.update_columns(agent_last_seen_at: nil) # rubocop:disable Rails/SkipsModelValidations
    stub = stub_request(:post, meta_url).to_return(meta_ok)

    perform

    expect(stub).not_to have_been_requested
  end

  it 'keeps trying later when WhatsApp rejects the receipt' do
    incoming('wamid.NEW')
    rejected = { status: 400, body: { error: { message: 'nope' } }.to_json, headers: { 'Content-Type' => 'application/json' } }
    stub_request(:post, meta_url).to_return(rejected, meta_ok)

    perform
    expect(conversation.reload.additional_attributes).not_to have_key(described_class::TRACKING_KEY)

    perform
    expect(conversation.reload.additional_attributes[described_class::TRACKING_KEY]).to be_present
    expect(a_request(:post, meta_url)).to have_been_made.twice
  end

  it 'does not crash on network failures' do
    incoming('wamid.NEW')
    stub_request(:post, meta_url).to_raise(Net::OpenTimeout)

    expect { perform }.not_to raise_error
  end

  it 'ignores messages that are too old for WhatsApp to accept' do
    incoming('wamid.ANCIENT', created_at: 40.days.ago)
    stub = stub_request(:post, meta_url).to_return(meta_ok)

    perform

    expect(stub).not_to have_been_requested
  end

  it 'ignores outgoing messages and messages without a WhatsApp id' do
    create(:message, conversation: conversation, inbox: inbox, account: inbox.account, message_type: :outgoing, source_id: 'wamid.OUT')
    incoming(nil)
    stub = stub_request(:post, meta_url).to_return(meta_ok)

    perform

    expect(stub).not_to have_been_requested
  end

  it 'respects a channel that turned read receipts off' do
    channel.update!(provider_config: channel.provider_config.merge('send_read_receipts' => false))
    incoming('wamid.NEW')
    stub = stub_request(:post, meta_url).to_return(meta_ok)

    perform

    expect(stub).not_to have_been_requested
  end

  it 'only works for WhatsApp Cloud channels' do
    dialog = create(:channel_whatsapp, provider: 'default', sync_templates: false, validate_provider_config: false)
    dialog_conversation = create(:conversation, inbox: dialog.inbox, account: dialog.account, agent_last_seen_at: Time.current)
    create(:message, conversation: dialog_conversation, inbox: dialog.inbox, account: dialog.account, message_type: :incoming, source_id: 'wamid.X')
    stub = stub_request(:post, meta_url).to_return(meta_ok)

    described_class.new(conversation: dialog_conversation).perform

    expect(stub).not_to have_been_requested
  end

  it 'ignores conversations of other channels' do
    web = create(:conversation, agent_last_seen_at: Time.current)
    stub = stub_request(:post, meta_url).to_return(meta_ok)

    expect { described_class.new(conversation: web).perform }.not_to raise_error
    expect(stub).not_to have_been_requested
  end
end
