# COESA: a two-channel call recording (one person per channel) becomes a transcript that says who
# spoke: each channel is transcribed on its own and the segments are interleaved by start time.
#   "Lucas: Olá, tudo bem?\nCliente: Tudo joia."
# Returns nil when the file is not stereo or the model gives no timestamps, so callers fall back
# to the plain transcript.
class Voice::SpeakerTranscriptService
  pattr_initialize [:path!, :labels!, :account!, { usage: {} }]

  def perform
    return unless stereo?

    Dir.mktmpdir('speaker-transcript') do |dir|
      segments = []
      split_channels(dir).each_with_index do |channel_path, index|
        channel = channel_segments(channel_path)
        return nil if channel.nil?

        segments.concat(channel.map { |segment| segment.merge('speaker' => labels[index]) })
      end
      self.class.format(segments)
    end
  end

  # [first channel, second channel] names: the agent who took the call and the contact.
  def self.labels(call, agent_first:)
    agent = call.accepted_by_agent&.available_name.presence || I18n.t('conversations.messages.voice_call.transcript_agent')
    contact = I18n.t('conversations.messages.voice_call.transcript_contact')
    agent_first ? [agent, contact] : [contact, agent]
  end

  # Consecutive segments of the same speaker become one line.
  def self.format(segments)
    lines = []
    segments.sort_by { |segment| segment['start'].to_f }.each do |segment|
      text = segment['text'].to_s.strip
      next if text.blank?

      if lines.last&.first == segment['speaker']
        lines.last[1] << " #{text}"
      else
        lines << [segment['speaker'], text.dup]
      end
    end
    lines.map { |speaker, text| "#{speaker}: #{text}" }.join("\n").presence
  end

  private

  def stereo?
    out, status = Open3.capture2('ffprobe', '-v', 'error', '-select_streams', 'a:0', '-show_entries', 'stream=channels',
                                 '-of', 'csv=p=0', path)
    status.success? && out.strip == '2'
  rescue Errno::ENOENT
    Rails.logger.warn('[SpeakerTranscript] ffprobe not installed; using the plain transcript')
    false
  end

  # Opus keeps each channel far below the 25 MB transcription limit even on long calls.
  def split_channels(dir)
    left = File.join(dir, 'left.ogg')
    right = File.join(dir, 'right.ogg')
    _out, err, status = Open3.capture3('ffmpeg', '-v', 'error', '-y', '-i', path,
                                       '-filter_complex', '[0:a]channelsplit=channel_layout=stereo[l][r]',
                                       '-map', '[l]', '-ac', '1', '-c:a', 'libopus', '-b:a', '24k', left,
                                       '-map', '[r]', '-ac', '1', '-c:a', 'libopus', '-b:a', '24k', right)
    raise "ffmpeg channel split failed: #{err}" unless status.success?

    [left, right]
  end

  def channel_segments(channel_path)
    Llm::SpeechToTextService.new(blob: nil, account: account, source: 'call', **usage).segments_for(channel_path)
  end
end
