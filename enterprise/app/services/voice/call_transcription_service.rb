class Voice::CallTranscriptionService
  pattr_initialize [:call!]

  def perform
    # Split so a publish failure can retry without re-running (and re-charging) transcription.
    transcribe if call.transcript.blank?
    publish(call.message) if call.transcript.present?
  end

  private

  def transcribe
    return unless call.recording.attached?
    return unless call.inbox.channel.transcription_enabled?
    return unless Llm::SpeechToTextService.available_for?(call.account)
    return if Llm::SpeechToTextService.too_large?(recording_blob)

    transcript = speaker_transcript || plain_transcript
    call.update!(transcript: transcript) if transcript.present?
  end

  def plain_transcript
    Llm::SpeechToTextService.new(blob: recording_blob, account: call.account, source: 'call',
                                 message_id: call.message&.id, call_id: call.id).perform
  end

  # COESA: the agent's leg is recorded in two channels (Voice::Provider::Twilio::TwimlBuilder), agent
  # first, then what the agent hears; calls made before that change have none and keep the plain transcript.
  def speaker_transcript
    return unless call.twilio?

    recording = agent_leg_recording
    return if recording.blank?

    channel = call.inbox.channel
    url = "https://api.twilio.com/2010-04-01/Accounts/#{channel.account_sid}/Recordings/#{recording.sid}.mp3?RequestedChannels=2"
    SafeFetch.fetch(url, http_basic_authentication: channel.basic_auth_credentials, allowed_content_type_prefixes: %w[audio/]) do |result|
      transcribe_speakers(result.tempfile.path)
    end
  rescue StandardError => e
    Rails.logger.warn("[SpeakerTranscript] call #{call.id}: plain transcript (#{e.class}: #{e.message})")
    nil
  end

  # shortcut: a leg recording Twilio is still processing when this job runs is skipped (plain
  # transcript); add a delayed retry if that shows up in practice.
  def agent_leg_recording
    client = call.inbox.channel.client
    call.agent_legs.keys.grep(/\ACA/).flat_map { |sid| client.recordings.list(call_sid: sid, limit: 5) }
        .select { |recording| recording.status == 'completed' && recording.channels.to_i == 2 }
        .max_by { |recording| recording.duration.to_i }
  end

  def transcribe_speakers(path)
    labels = Voice::SpeakerTranscriptService.labels(call, agent_first: true)
    Voice::SpeakerTranscriptService.new(path: path, labels: labels, account: call.account,
                                        usage: { message_id: call.message&.id, call_id: call.id }).perform
  end

  def publish(message)
    return if message.blank?

    # Reindex before broadcasting: if reindexing fails and the job retries,
    # the transcript is already present so only publish reruns. Sending the
    # update event first would resend it to clients on every such retry.
    message.reindex if ChatwootApp.advanced_search_allowed?

    # Rebroadcast the message so connected clients pick up the embedded Call
    # payload (now with transcript) without a refetch.
    message.reload.send_update_event
  end

  def recording_blob
    call.recording.blob
  end
end
