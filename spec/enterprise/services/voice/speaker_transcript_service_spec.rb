require 'rails_helper'

RSpec.describe Voice::SpeakerTranscriptService do
  describe '.format' do
    it 'interleaves both channels by start time and joins consecutive pieces of one speaker' do
      segments = [
        { 'start' => 8.4, 'text' => ' Eu queria te mostrar a proposta.', 'speaker' => 'Lucas' },
        { 'start' => 0.0, 'text' => ' Olá, tudo bem?', 'speaker' => 'Lucas' },
        { 'start' => 4.7, 'text' => ' Oi, tudo joia?', 'speaker' => 'Cliente' },
        { 'start' => 6.8, 'text' => ' Pode falar.', 'speaker' => 'Cliente' },
        { 'start' => 14.6, 'text' => '   ', 'speaker' => 'Cliente' }
      ]

      expect(described_class.format(segments)).to eq(
        "Lucas: Olá, tudo bem?\nCliente: Oi, tudo joia? Pode falar.\nLucas: Eu queria te mostrar a proposta."
      )
    end

    it 'returns nil when nobody said anything' do
      expect(described_class.format([{ 'start' => 0, 'text' => ' ', 'speaker' => 'Lucas' }])).to be_nil
    end
  end

  describe '.labels' do
    let(:agent) { create(:user, name: 'Lucas Vendedor', display_name: 'Lucas') }
    let(:contact) { create(:contact, name: 'Luan Costa') }

    def call_double(accepted_by_agent: nil, contact: nil, message: nil, conversation: nil)
      instance_double(Call, accepted_by_agent: accepted_by_agent, contact: contact, message: message, conversation: conversation)
    end

    it 'names the agent who took the call and the contact, in channel order' do
      call = call_double(accepted_by_agent: agent, contact: contact)

      expect(described_class.labels(call, agent_first: true)).to eq(['Lucas', 'Luan Costa'])
      expect(described_class.labels(call, agent_first: false)).to eq(['Luan Costa', 'Lucas'])
    end

    it "uses the conversation's contact and the agent who sent the call message when the call lacks them" do
      conversation = instance_double(Conversation, contact: contact, assignee: nil)
      message = instance_double(Message, sender: agent)

      expect(described_class.labels(call_double(message: message, conversation: conversation), agent_first: true))
        .to eq(['Lucas', 'Luan Costa'])
    end

    it 'falls back to generic labels when there is no agent and the contact is only a phone number' do
      call = call_double(contact: create(:contact, name: '+55 (31) 99999-0000'))

      expect(described_class.labels(call, agent_first: true)).to eq(
        [I18n.t('conversations.messages.voice_call.transcript_agent'), I18n.t('conversations.messages.voice_call.transcript_contact')]
      )
    end
  end
end
