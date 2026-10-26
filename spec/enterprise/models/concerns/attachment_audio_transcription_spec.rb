require 'rails_helper'

# COESA: call recordings are transcribed automatically, voice notes only on request.
RSpec.describe Attachment do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }

  def create_audio(message)
    message.attachments.create!(account: account, file_type: :audio)
  end

  it 'queues a call recording for transcription' do
    message = create(:message, account: account, conversation: conversation, content_type: 'voice_call')

    expect { create_audio(message) }.to have_enqueued_job(Messages::AudioTranscriptionJob)
  end

  it 'does not queue a voice note' do
    message = create(:message, account: account, conversation: conversation)

    expect { create_audio(message) }.not_to have_enqueued_job(Messages::AudioTranscriptionJob)
  end

  it 'queues a voice note when automatic voice-note transcription is on' do
    InstallationConfig.find_or_create_by!(name: 'AUDIO_TRANSCRIPTION_AUTO_VOICE_NOTES') { |c| c.value = true }
    message = create(:message, account: account, conversation: conversation)

    expect { create_audio(message) }.to have_enqueued_job(Messages::AudioTranscriptionJob)
  end
end
