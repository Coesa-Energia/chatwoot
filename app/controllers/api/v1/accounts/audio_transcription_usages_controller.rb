# COESA: monthly transcription spend for the account settings page (admins only).
class Api::V1::Accounts::AudioTranscriptionUsagesController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?

  def index
    render json: {
      months: AudioTranscriptionUsage.where(account: Current.account).monthly_summary,
      cost_per_minute: config_number('AUDIO_TRANSCRIPTION_COST_PER_MINUTE'),
      monthly_fixed_cost: config_number('AUDIO_TRANSCRIPTION_MONTHLY_COST')
    }
  end

  private

  def config_number(name)
    value = InstallationConfig.find_by(name: name)&.value
    value.present? ? value.to_s.tr(',', '.').to_f : nil
  end
end
