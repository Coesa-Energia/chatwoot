require 'rails_helper'

RSpec.describe 'Audio transcription usage API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:url) { "/api/v1/accounts/#{account.id}/audio_transcription_usages" }

  describe 'GET /api/v1/accounts/:account_id/audio_transcription_usages' do
    before do
      AudioTranscriptionUsage.create!(account: account, source: 'call', audio_seconds: 90, processing_ms: 4000)
      AudioTranscriptionUsage.create!(account: account, source: 'voice_note', audio_seconds: 30, processing_ms: 1000, success: false)
      AudioTranscriptionUsage.create!(account: create(:account), source: 'call', audio_seconds: 600)
      InstallationConfig.find_or_create_by!(name: 'AUDIO_TRANSCRIPTION_COST_PER_MINUTE') { |c| c.value = '0,006' }
    end

    it 'returns the monthly totals of the account to an administrator' do
      get url, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body['months']).to eq([{ 'month' => Time.current.strftime('%Y-%m'), 'total' => 2, 'calls' => 1, 'voice_notes' => 1,
                                      'failures' => 1, 'audio_seconds' => 120.0, 'processing_seconds' => 5.0 }])
      expect(body['cost_per_minute']).to eq(0.006)
      expect(body['monthly_fixed_cost']).to be_nil
    end

    it 'is not available to agents' do
      get url, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
