require 'rails_helper'

RSpec.describe 'Message transcription on request', type: :request do
  let(:account) { create(:account, audio_transcriptions: true) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:conversation) { create(:conversation, account: account) }
  let(:message) { create(:message, account: account, conversation: conversation) }
  let(:url) { "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/messages/#{message.id}/transcribe" }

  before do
    create(:inbox_member, inbox: conversation.inbox, user: agent)
    InstallationConfig.find_or_create_by!(name: 'AUDIO_TRANSCRIPTION_API_URL') { |c| c.value = 'http://whisper:8000/v1' }
  end

  it 'queues the audio attachments that have no transcript yet' do
    pending_audio = message.attachments.create!(account: account, file_type: :audio)
    message.attachments.create!(account: account, file_type: :audio, meta: { transcribed_text: 'Já feito' })
    message.attachments.create!(account: account, file_type: :image)

    expect do
      post url, headers: agent.create_new_auth_token, as: :json
    end.to have_enqueued_job(Messages::AudioTranscriptionJob).with(pending_audio.id).exactly(:once)
    expect(response).to have_http_status(:accepted)
  end

  it 'refuses when transcription is off for the account' do
    account.update!(audio_transcriptions: false)

    post url, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
  end
end
