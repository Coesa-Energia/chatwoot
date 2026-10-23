require 'rails_helper'

describe Whatsapp::WebhookPayloadSplitter do
  def payload_with(**value)
    { object: 'whatsapp_business_account', entry: [{ id: 'WABA', changes: [{ field: 'messages', value: value }] }] }
  end

  def message(id, from)
    { id: id, from: from, type: 'text', text: { body: "hi #{id}" } }
  end

  let(:metadata) { { display_phone_number: '551100000000', phone_number_id: '123' } }

  it 'returns a single-message payload unchanged' do
    payload = payload_with(metadata: metadata, contacts: [{ wa_id: '5511999990001' }], messages: [message('wamid.1', '5511999990001')])

    expect(described_class.split(payload)).to eq([payload.with_indifferent_access])
  end

  it 'returns a status-only payload unchanged' do
    payload = payload_with(metadata: metadata, statuses: [{ id: 'wamid.1', status: 'delivered' }])

    expect(described_class.split(payload)).to eq([payload.with_indifferent_access])
  end

  it 'does not touch payloads that are not from a WhatsApp Business Account (360dialog)' do
    payload = { messages: [message('wamid.1', '5511999990001'), message('wamid.2', '5511999990002')] }

    expect(described_class.split(payload)).to eq([payload.with_indifferent_access])
  end

  context 'when several messages are batched' do
    let(:payload) do
      payload_with(
        metadata: metadata,
        contacts: [{ wa_id: '5511999990001', profile: { name: 'Ana' } }, { wa_id: '5511999990002', profile: { name: 'Bruno' } }],
        messages: [message('wamid.1', '5511999990001'), message('wamid.2', '5511999990002'), message('wamid.3', '5511999990001')]
      )
    end

    it 'returns one payload per message, in order' do
      result = described_class.split(payload)

      expect(result.size).to eq(3)
      expect(result.map { |p| p.dig(:entry, 0, :changes, 0, :value, :messages).map { |m| m[:id] } }).to eq([['wamid.1'], ['wamid.2'], ['wamid.3']])
    end

    it 'keeps the contact that belongs to each message as the first contact' do
      result = described_class.split(payload)

      senders = result.map { |p| p.dig(:entry, 0, :changes, 0, :value, :contacts, 0, :wa_id) }
      expect(senders).to eq(%w[5511999990001 5511999990002 5511999990001])
    end

    it 'preserves the metadata used to find the channel' do
      result = described_class.split(payload)

      expect(result.map { |p| p.dig(:entry, 0, :changes, 0, :value, :metadata, :phone_number_id) }.uniq).to eq(['123'])
      expect(result.map { |p| p[:object] }.uniq).to eq(['whatsapp_business_account'])
    end
  end

  it 'separates messages from statuses and one status per payload' do
    payload = payload_with(
      metadata: metadata,
      messages: [message('wamid.1', '5511999990001')],
      statuses: [{ id: 'wamid.9', status: 'sent' }, { id: 'wamid.8', status: 'read' }]
    )

    result = described_class.split(payload)
    values = result.map { |p| p.dig(:entry, 0, :changes, 0, :value) }

    expect(result.size).to eq(3)
    expect(values.count { |v| v.key?(:messages) }).to eq(1)
    expect(values.select { |v| v.key?(:statuses) }.map { |v| v[:statuses].map { |s| s[:id] } }).to eq([['wamid.9'], ['wamid.8']])
    expect(values.none? { |v| v.key?(:messages) && v.key?(:statuses) }).to be(true)
  end

  it 'splits across several entries' do
    payload = {
      object: 'whatsapp_business_account',
      entry: [
        { id: 'A', changes: [{ field: 'messages', value: { metadata: metadata, messages: [message('wamid.1', '5511999990001')] } }] },
        { id: 'B', changes: [{ field: 'messages', value: { metadata: metadata, messages: [message('wamid.2', '5511999990002')] } }] }
      ]
    }

    result = described_class.split(payload)

    expect(result.map { |p| p.dig(:entry, 0, :id) }).to eq(%w[A B])
  end

  it 'keeps all contacts when none can be matched to a message' do
    payload = payload_with(
      metadata: metadata,
      contacts: [{ wa_id: 'unknown' }],
      messages: [message('wamid.1', '5511999990001'), message('wamid.2', '5511999990002')]
    )

    result = described_class.split(payload)

    expect(result.map { |p| p.dig(:entry, 0, :changes, 0, :value, :contacts).size }).to eq([1, 1])
  end
end
