class Messages::AudioTranscriptionService
  attr_reader :attachment, :message, :account

  def initialize(attachment)
    @attachment = attachment
    @message = attachment.message
    @account = message&.account
  end

  def perform
    return { error: 'Message not found' } if message.blank?
    return { error: 'Transcription disabled for this inbox' } if call_recording_transcription_disabled?
    return { error: 'Transcription limit exceeded' } unless Llm::SpeechToTextService.available_for?(account)
    return { error: 'Audio too large for transcription' } if Llm::SpeechToTextService.too_large?(attachment.file&.blob)

    transcriptions = transcribe_audio
    Rails.logger.info "Audio transcription successful: #{transcriptions}"
    { success: true, transcriptions: transcriptions }
  rescue Faraday::UnauthorizedError
    Rails.logger.warn('Skipping audio transcription: OpenAI configuration is invalid or disabled (401 Unauthorized).')
    { error: 'OpenAI configuration is invalid or disabled (401)' }
  end

  private

  # Call recordings honour the inbox's "Transcribe recordings" setting; ordinary voice notes don't.
  def call_recording_transcription_disabled?
    message.voice_call? && !message.inbox.channel.transcription_enabled?
  end

  # COESA: the same attachment can be queued twice (seen in prod: two jobs a few seconds apart);
  # the lock makes the second one skip instead of paying for the same audio again.
  LOCK_TIMEOUT = 10.minutes

  def transcribe_audio
    transcribed_text = existing_transcription
    return transcribed_text if transcribed_text.present?

    lock_key = format('AUDIO_TRANSCRIPTION_LOCK::%<id>d', id: attachment.id)
    lock_manager = Redis::LockManager.new
    return '' unless lock_manager.lock(lock_key, LOCK_TIMEOUT)

    begin
      transcribed_text = existing_transcription(reload: true)
      return transcribed_text if transcribed_text.present?

      transcribed_text = Llm::SpeechToTextService.new(blob: attachment.file.blob, account: account,
                                                      source: message.voice_call? ? 'call' : 'voice_note',
                                                      message_id: message.id).perform
      update_transcription(transcribed_text)
      transcribed_text
    ensure
      lock_manager.unlock(lock_key)
    end
  end

  def existing_transcription(reload: false)
    attachment.reload if reload
    attachment.meta&.[]('transcribed_text') || ''
  end

  def update_transcription(transcribed_text)
    return if transcribed_text.blank?

    attachment.update!(meta: (attachment.meta || {}).merge('transcribed_text' => transcribed_text))
    message.reload.send_update_event

    return unless ChatwootApp.advanced_search_allowed?

    message.reindex
  end
end
