require 'rails_helper'

RSpec.describe Llm::SpeechToTextService, type: :service do
  let(:account) { create(:account, audio_transcriptions: true) }
  let(:conversation) { create(:conversation, account: account) }
  let(:message) { create(:message, account: account, conversation: conversation) }
  let(:attachment) { message.attachments.create!(account: account, file_type: :audio) }
  let(:service) { described_class.new(blob: attachment.file.blob, account: account) }

  before do
    InstallationConfig.find_or_create_by!(name: 'CAPTAIN_OPEN_AI_API_KEY') { |config| config.value = 'test-api-key' }
    InstallationConfig.find_or_create_by!(name: 'CAPTAIN_OPEN_AI_MODEL') { |config| config.value = 'gpt-6-luna' }

    attachment.file.attach(
      io: File.open(Rails.public_path.join('audio/widget/ding.mp3')),
      filename: 'speech',
      content_type: 'audio/mpeg'
    )
  end

  describe '.available_for?' do
    before do
      allow(account).to receive(:usage_limits).and_return(
        {
          agents: ChatwootApp.max_limit,
          inboxes: ChatwootApp.max_limit,
          captain: { responses: { current_available: 100 } }
        }
      )
    end

    it 'is false when the captain_integration feature is disabled' do
      account.disable_features!('captain_integration')

      expect(described_class.available_for?(account)).to be(false)
    end

    it 'is false when audio transcriptions are disabled on the account' do
      account.enable_features!('captain_integration')
      account.update!(audio_transcriptions: false)

      expect(described_class.available_for?(account)).to be(false)
    end

    it 'is false when no captain responses are available' do
      account.enable_features!('captain_integration')
      allow(account).to receive(:usage_limits).and_return(captain: { responses: { current_available: 0 } })

      expect(described_class.available_for?(account)).to be(false)
    end

    it 'is true when the feature, setting and credits are all present' do
      account.enable_features!('captain_integration')

      expect(described_class.available_for?(account)).to be(true)
    end
  end

  describe '.too_large?' do
    it 'is false when the blob is missing' do
      expect(described_class.too_large?(nil)).to be(false)
    end

    it 'is true beyond the byte limit' do
      allow(attachment.file.blob).to receive(:byte_size).and_return(described_class::BYTE_LIMIT + 1)

      expect(described_class.too_large?(attachment.file.blob)).to be(true)
    end
  end

  describe '#fetch_audio_file' do
    it 'normalizes .oga uploads without changing the audio bytes or stored filename' do
      audio_path = Rails.root.join('spec/assets/sample.ogg')
      attachment.file.attach(io: File.open(audio_path), filename: 'voice.oga', content_type: 'audio/ogg')

      temp_file_path = service.send(:fetch_audio_file)

      expect(File.extname(temp_file_path)).to eq('.ogg')
      expect(File.binread(temp_file_path)).to eq(File.binread(audio_path))
      expect(attachment.file.blob.filename.to_s).to eq('voice.oga')
    ensure
      FileUtils.rm_f(temp_file_path) if temp_file_path.present?
    end

    it 'adds extension from content type when filename has no extension' do
      temp_file_path = service.send(:fetch_audio_file)

      expect(File.extname(temp_file_path)).to eq('.mpeg')
    ensure
      FileUtils.rm_f(temp_file_path) if temp_file_path.present?
    end
  end

  describe '#perform' do
    let(:audio_api) { double('audio_api') } # rubocop:disable RSpec/VerifiedDoubles
    let(:audio_file_path) { Rails.root.join('tmp/speech_to_text_service_spec.mp3').to_s }

    before do
      File.binwrite(audio_file_path, 'audio')
      allow(service).to receive(:fetch_audio_file).and_return(audio_file_path)
      allow(account).to receive(:increment_response_usage)
      allow(service.client).to receive(:audio).and_return(audio_api)
    end

    after do
      FileUtils.rm_f(audio_file_path)
    end

    it 'uses the audio transcription feature model' do
      expect(audio_api).to receive(:transcribe).with(
        parameters: hash_including(model: 'gpt-transcribe', temperature: 0.0)
      ).and_return({ 'text' => 'Audio transcript' })

      expect(service.perform).to eq('Audio transcript')
    end

    it 'consumes a captain response credit when text comes back' do
      allow(audio_api).to receive(:transcribe).and_return({ 'text' => 'Audio transcript' })

      service.perform

      expect(account).to have_received(:increment_response_usage)
    end

    it 'does not consume a credit when the transcription is blank' do
      allow(audio_api).to receive(:transcribe).and_return({ 'text' => '' })

      service.perform

      expect(account).not_to have_received(:increment_response_usage)
    end
  end

  describe 'with a custom transcription server (self-hosted Whisper)' do
    let(:audio_api) { double('audio_api') } # rubocop:disable RSpec/VerifiedDoubles
    let(:audio_file_path) { Rails.root.join('tmp/speech_to_text_service_custom_spec.mp3').to_s }

    before do
      InstallationConfig.find_or_create_by!(name: 'AUDIO_TRANSCRIPTION_API_URL') { |c| c.value = 'http://whisper:8000/v1' }
      InstallationConfig.find_or_create_by!(name: 'AUDIO_TRANSCRIPTION_MODEL') { |c| c.value = 'Systran/faster-whisper-small' }
      InstallationConfig.find_or_create_by!(name: 'AUDIO_TRANSCRIPTION_LANGUAGE') { |c| c.value = 'pt' }
    end

    it 'is available with only the account toggle, without Captain or credits' do
      account.disable_features!('captain_integration')

      expect(described_class.available_for?(account)).to be(true)
      account.update!(audio_transcriptions: false)
      expect(described_class.available_for?(account)).to be(false)
    end

    it 'sends the audio to the configured server, model and language without consuming Captain credits' do
      File.binwrite(audio_file_path, 'audio')
      allow(service).to receive(:fetch_audio_file).and_return(audio_file_path)
      allow(account).to receive(:increment_response_usage)
      allow(service.client).to receive(:audio).and_return(audio_api)
      expect(audio_api).to receive(:transcribe).with(
        parameters: hash_including(model: 'Systran/faster-whisper-small', language: 'pt', temperature: 0.0)
      ).and_return({ 'text' => 'Bom dia' })

      expect(service.perform).to eq('Bom dia')
      expect(service.client.uri_base).to eq('http://whisper:8000/v1')
      expect(account).not_to have_received(:increment_response_usage)
    ensure
      FileUtils.rm_f(audio_file_path)
    end

    context 'when recording usage' do
      let(:service) do
        described_class.new(blob: attachment.file.blob, account: account, source: 'call', message_id: message.id, call_id: 42)
      end

      before do
        InstallationConfig.find_or_create_by!(name: 'AUDIO_TRANSCRIPTION_PROMPT') { |c| c.value = 'Coesa Energia, Cemig' }
        File.binwrite(audio_file_path, 'audio')
        allow(service).to receive(:fetch_audio_file).and_return(audio_file_path)
        allow(service.client).to receive(:audio).and_return(audio_api)
      end

      after { FileUtils.rm_f(audio_file_path) }

      it 'asks Whisper for verbose_json without the vocabulary prompt and logs the audio duration' do
        expect(audio_api).to receive(:transcribe) do |parameters:|
          expect(parameters).to include(response_format: 'verbose_json')
          expect(parameters).not_to have_key(:prompt)
          { 'text' => ' Bom dia ', 'duration' => 12.5 }
        end

        expect(service.perform).to eq('Bom dia')

        usage = AudioTranscriptionUsage.last
        expect(usage).to have_attributes(account_id: account.id, source: 'call', message_id: message.id, call_id: 42,
                                         model: 'Systran/faster-whisper-small', audio_seconds: 12.5, characters: 9, success: true)
        expect(usage.processing_ms).to be >= 0
      end

      it 'logs a failed request and re-raises the error' do
        allow(audio_api).to receive(:transcribe).and_raise(Faraday::TimeoutError)

        expect { service.perform }.to raise_error(Faraday::TimeoutError)
        expect(AudioTranscriptionUsage.last).to have_attributes(success: false, audio_seconds: nil)
      end

      it 'does not ask for verbose_json from models that do not support it' do
        InstallationConfig.find_by(name: 'AUDIO_TRANSCRIPTION_MODEL').update!(value: 'gpt-4o-mini-transcribe')
        expect(audio_api).to receive(:transcribe).with(
          parameters: hash_excluding(:response_format)
        ).and_return({ 'text' => 'Bom dia' })

        described_class.new(blob: attachment.file.blob, account: account).tap do |other|
          allow(other).to receive(:fetch_audio_file).and_return(audio_file_path)
          allow(other.client).to receive(:audio).and_return(audio_api)
        end.perform
      end

      it 'sends the vocabulary prompt on voice notes' do
        expect(audio_api).to receive(:transcribe).with(
          parameters: hash_including(prompt: 'Coesa Energia, Cemig')
        ).and_return({ 'text' => 'Bom dia' })

        described_class.new(blob: attachment.file.blob, account: account).tap do |other|
          allow(other).to receive(:fetch_audio_file).and_return(audio_file_path)
          allow(other.client).to receive(:audio).and_return(audio_api)
        end.perform
      end

      it 'uses the call model on calls when one is set' do
        InstallationConfig.find_or_create_by!(name: 'AUDIO_TRANSCRIPTION_CALL_MODEL') { |c| c.value = 'deepdml/faster-whisper-large-v3-turbo-ct2' }
        call_service = described_class.new(blob: attachment.file.blob, account: account, source: 'call')
        voice_note_service = described_class.new(blob: attachment.file.blob, account: account)

        expect(call_service.transcription_model).to eq('deepdml/faster-whisper-large-v3-turbo-ct2')
        expect(voice_note_service.transcription_model).to eq('Systran/faster-whisper-small')
      end
    end

    describe '#segments_for' do
      let(:service) { described_class.new(blob: nil, account: account, source: 'call') }

      before do
        File.binwrite(audio_file_path, 'audio')
        allow(service.client).to receive(:audio).and_return(audio_api)
      end

      after { FileUtils.rm_f(audio_file_path) }

      def word(text, start, finish)
        { 'word' => text, 'start' => start, 'end' => finish }
      end

      it "keeps confident speech Whisper scores as likely silence and drops only unsure silence (Whisper's rule)" do
        allow(audio_api).to receive(:transcribe).and_return(
          'segments' => [
            { 'start' => 2.5, 'end' => 3.3, 'no_speech_prob' => 0.67, 'avg_logprob' => -0.82, 'text' => ' Você viu?' },
            { 'start' => 6.0, 'end' => 7.0, 'no_speech_prob' => 0.9, 'avg_logprob' => -1.4, 'text' => ' Obrigado.' }
          ],
          'words' => [word(' Você', 2.58, 2.9), word(' viu?', 2.9, 3.2), word(' Obrigado.', 6.1, 6.8)]
        )

        expect(service.segments_for(audio_file_path)).to eq([{ 'start' => 2.58, 'text' => ' Você viu?' }])
      end

      it 'keeps a phrase Whisper repeated in a loop only once' do
        allow(audio_api).to receive(:transcribe).and_return(
          'segments' => [{ 'start' => 1.1, 'end' => 7.9, 'no_speech_prob' => 0.3, 'avg_logprob' => -0.8,
                           'text' => ' Vou fazer um teste, um teste, um teste, um teste, um teste.' }]
        )

        expect(service.segments_for(audio_file_path)).to eq([{ 'start' => 1.1, 'end' => 7.9, 'no_speech_prob' => 0.3,
                                                               'avg_logprob' => -0.8, 'text' => ' Vou fazer um teste, um teste.' }])
      end
    end
  end

  describe '.without_loops' do
    it 'leaves ordinary repetition alone and collapses three or more repeats' do
      expect(described_class.without_loops('Tudo bem? Tudo bem? Ah, sim.')).to eq('Tudo bem? Tudo bem? Ah, sim.')
      expect(described_class.without_loops('Alô, tá bom, tá bom, tá bom, tá bom. Ah, sim.')).to eq('Alô, tá bom, tá bom. Ah, sim.')
    end
  end
end
