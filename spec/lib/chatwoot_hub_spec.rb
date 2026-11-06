require 'rails_helper'

describe ChatwootHub do
  describe '.base_url' do
    it 'uses the static hub url' do
      expect(described_class::DEFAULT_BASE_URL).to eq('https://hub.2.chatwoot.com')
      expect(described_class.base_url).to eq('https://hub.2.chatwoot.com')
    end
  end

  it 'generates installation identifier' do
    installation_identifier = described_class.installation_identifier
    expect(installation_identifier).not_to be_nil
    expect(described_class.installation_identifier).to eq installation_identifier
  end

  # COESA: o fork desligou toda chamada ao Hub. Os métodos respondem localmente.
  context 'when fetching sync_with_hub' do
    it 'returns the local version without calling the hub' do
      allow(RestClient).to receive(:post)
      expect(described_class.sync_with_hub['version']).to eq Chatwoot.config[:version]
      expect(RestClient).not_to have_received(:post)
    end
  end

  context 'when register instance' do
    it 'does not send the registration' do
      allow(RestClient).to receive(:post)
      expect(described_class.register_instance('test', 'test', 'test@test.com')).to be(true)
      expect(RestClient).not_to have_received(:post)
    end
  end

  context 'when sending events' do
    it 'does not send instance events' do
      allow(RestClient).to receive(:post)
      described_class.emit_event('sample_event', { 'sample_data' => 'sample_data' })
      expect(RestClient).not_to have_received(:post)
    end
  end
end
