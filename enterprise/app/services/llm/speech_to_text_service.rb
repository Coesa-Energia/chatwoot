# Blob-in, text-out audio transcription shared by voice-note attachments
# (Messages::AudioTranscriptionService) and voice-call recordings
# (Voice::CallTranscriptionService).
class Llm::SpeechToTextService < Llm::LegacyBaseOpenAiService
  include Integrations::LlmInstrumentation

  # OpenAI's transcription endpoint hard limit is 25 MB *decimal* (25_000_000), not
  # binary (25.megabytes = 26_214_400) — using the binary form leaks the 25.0–26.2 MB
  # range to the API as 413s. Long audio (~70+ min Opus) keeps the source audio but
  # skips transcription.
  BYTE_LIMIT = 25_000_000

  attr_reader :blob, :account, :transcription_model

  # COESA: a transcription server set in Super Admin (self-hosted Whisper or any OpenAI-compatible API)
  # replaces Captain here: no Captain feature or response credits needed, only the account toggle.
  CUSTOM_SERVER_TIMEOUT = 300 # seconds: CPU-only Whisper can take a while on long audio
  # Whisper models answer verbose_json, which carries the audio duration used for the spend report;
  # gpt-4o-*-transcribe only answers json.
  VERBOSE_JSON_MODEL = /whisper/i

  def self.config_value(name)
    InstallationConfig.find_by(name: name)&.value.presence
  end

  def self.custom_server?
    config_value('AUDIO_TRANSCRIPTION_API_URL').present?
  end

  # Voice notes are transcribed only when an agent asks, unless Super Admin turns automatic transcription on;
  # call recordings are always transcribed.
  def self.auto_voice_notes?
    ActiveModel::Type::Boolean.new.cast(config_value('AUDIO_TRANSCRIPTION_AUTO_VOICE_NOTES')) || false
  end

  # Transcription runs on Captain's OpenAI credentials and consumes its response credits (unless a custom server is set).
  def self.available_for?(account)
    return account.audio_transcriptions.present? if custom_server?
    return false unless account.feature_enabled?('captain_integration')
    return false if account.audio_transcriptions.blank?

    account.usage_limits[:captain][:responses][:current_available].positive?
  end

  def self.too_large?(blob)
    blob.present? && blob.byte_size > BYTE_LIMIT
  end

  # source/message_id/call_id only label the AudioTranscriptionUsage row.
  def initialize(blob:, account:, source: 'voice_note', message_id: nil, call_id: nil)
    @blob = blob
    @account = account
    @usage_context = { source: source, message_id: message_id, call_id: call_id }
    if self.class.custom_server?
      setup_custom_server
    else
      super()
      @transcription_model = Llm::FeatureRouter.resolve(feature: 'audio_transcription', account: account)[:model]
    end
  end

  def perform
    temp_file_path = fetch_audio_file
    transcribed_text = nil

    File.open(temp_file_path, 'rb') do |file|
      transcribed_text = instrument_audio_transcription(instrumentation_params(temp_file_path)) do
        request_transcription(file)
      end
    end

    account.increment_response_usage if transcribed_text.present? && !@custom_server
    transcribed_text
  ensure
    FileUtils.rm_f(temp_file_path) if temp_file_path.present?
  end

  private

  def request_transcription(file)
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    # temperature: 0.0 minimises hallucinations on silence / near-silent
    # audio; non-zero values trigger spiraling repeats — well-documented
    # behaviour across OpenAI transcription models.
    response = @client.audio.transcribe(
      parameters: {
        model: transcription_model,
        file: file,
        temperature: 0.0,
        language: @language,
        prompt: @prompt,
        response_format: verbose_json? ? 'verbose_json' : nil
      }.compact
    )
    response['text'].to_s.strip.presence
  ensure
    record_usage(response, started_at)
  end

  def verbose_json?
    transcription_model.to_s.match?(VERBOSE_JSON_MODEL)
  end

  # A failed log write must never lose a transcript that was already paid for.
  def record_usage(response, started_at)
    return if account.blank?

    AudioTranscriptionUsage.create!(
      account: account, model: transcription_model, **@usage_context,
      audio_seconds: response.is_a?(Hash) ? response['duration'] : nil,
      processing_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round,
      characters: response.is_a?(Hash) ? response['text'].to_s.length : 0,
      success: response.is_a?(Hash) && response['text'].present?
    )
  rescue StandardError => e
    Rails.logger.warn("Could not record audio transcription usage: #{e.message}")
  end

  def setup_custom_server
    @custom_server = true
    # A self-hosted Whisper usually takes no key; the client still requires a value.
    @client = OpenAI::Client.new(
      access_token: self.class.config_value('AUDIO_TRANSCRIPTION_API_KEY') || 'no-key',
      uri_base: self.class.config_value('AUDIO_TRANSCRIPTION_API_URL'),
      request_timeout: CUSTOM_SERVER_TIMEOUT,
      log_errors: Rails.env.development?
    )
    @transcription_model = self.class.config_value('AUDIO_TRANSCRIPTION_MODEL') || 'whisper-1'
    @language = self.class.config_value('AUDIO_TRANSCRIPTION_LANGUAGE')
    # Whisper is steered by a short text in the audio's language: names and jargon it would otherwise misspell.
    @prompt = self.class.config_value('AUDIO_TRANSCRIPTION_PROMPT')
  end

  def fetch_audio_file
    temp_dir = Rails.root.join('tmp/uploads/audio-transcriptions')
    FileUtils.mkdir_p(temp_dir)
    # OpenAI rejects .oga filenames even when the bytes contain valid Ogg audio.
    temp_file_name = "#{blob.key}-#{blob.filename}".sub(/\.oga\z/i, '.ogg')

    if blob.filename.extension_without_delimiter.blank?
      extension = extension_from_content_type(blob.content_type)
      temp_file_name = "#{temp_file_name}.#{extension}" if extension.present?
    end

    temp_file_path = File.join(temp_dir, temp_file_name)

    File.open(temp_file_path, 'wb') do |file|
      blob.open do |blob_file|
        IO.copy_stream(blob_file, file)
      end
    end

    temp_file_path
  end

  def extension_from_content_type(content_type)
    subtype = content_type.to_s.downcase.split(';').first.to_s.split('/').last.to_s
    return if subtype.blank?

    {
      'x-m4a' => 'm4a',
      'x-wav' => 'wav',
      'x-mp3' => 'mp3'
    }.fetch(subtype, subtype)
  end

  def instrumentation_params(file_path)
    {
      span_name: 'llm.messages.audio_transcription',
      model: transcription_model,
      account_id: account&.id,
      feature_name: 'audio_transcription',
      file_path: file_path
    }
  end
end
