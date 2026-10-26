# == Schema Information
#
# Table name: audio_transcription_usages
#
#  id            :bigint           not null, primary key
#  audio_seconds :decimal(10, 2)
#  characters    :integer          default(0), not null
#  model         :string
#  processing_ms :integer
#  source        :string           not null
#  success       :boolean          default(TRUE), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  account_id    :bigint           not null
#  call_id       :bigint
#  message_id    :bigint
#
# Indexes
#
#  index_audio_transcription_usages_on_account_id_and_created_at  (account_id,created_at)
#

# COESA: one row per transcription request (Llm::SpeechToTextService), used to report Whisper spend.
class AudioTranscriptionUsage < ApplicationRecord
  SOURCES = %w[call voice_note].freeze

  belongs_to :account

  validates :source, inclusion: { in: SOURCES }

  MONTH = Arel.sql("date_trunc('month', created_at)")
  SUMMARY_COLUMNS = [
    MONTH,
    Arel.sql('COUNT(*)'),
    Arel.sql("COUNT(*) FILTER (WHERE source = 'call')"),
    Arel.sql('COUNT(*) FILTER (WHERE NOT success)'),
    Arel.sql('COALESCE(SUM(audio_seconds), 0)'),
    Arel.sql('COALESCE(SUM(processing_ms), 0)')
  ].freeze

  # Monthly totals for the last `months` months, newest first.
  def self.monthly_summary(months: 6)
    where(created_at: months.months.ago.beginning_of_month..).group(MONTH).order(MONTH.desc)
                                                             .pluck(*SUMMARY_COLUMNS).map { |row| summary_row(*row) }
  end

  def self.summary_row(month, total, calls, failures, audio_seconds, processing_ms) # rubocop:disable Metrics/ParameterLists
    { month: month.strftime('%Y-%m'), total: total, calls: calls, voice_notes: total - calls, failures: failures,
      audio_seconds: audio_seconds.to_f.round(1), processing_seconds: (processing_ms / 1000.0).round(1) }
  end
  private_class_method :summary_row
end
