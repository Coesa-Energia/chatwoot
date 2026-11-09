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
    let(:agent) { create(:user) }

    it 'names the agent who took the call and the contact, in channel order' do
      call = instance_double(Call, accepted_by_agent: agent)

      contact = I18n.t('conversations.messages.voice_call.transcript_contact')
      expect(described_class.labels(call, agent_first: true)).to eq([agent.available_name, contact])
      expect(described_class.labels(call, agent_first: false)).to eq([contact, agent.available_name])
    end

    it 'falls back to a generic agent label' do
      call = instance_double(Call, accepted_by_agent: nil)

      expect(described_class.labels(call, agent_first: true).first).to eq(I18n.t('conversations.messages.voice_call.transcript_agent'))
    end
  end
end
