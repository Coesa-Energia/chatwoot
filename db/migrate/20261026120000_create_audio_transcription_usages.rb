# COESA: one row per request to the transcription server, so spend can be measured per account and month.
class CreateAudioTranscriptionUsages < ActiveRecord::Migration[7.1]
  def change
    create_table :audio_transcription_usages do |t|
      t.references :account, null: false, index: false
      t.string :source, null: false
      t.bigint :message_id
      t.bigint :call_id
      t.string :model
      t.decimal :audio_seconds, precision: 10, scale: 2
      t.integer :processing_ms
      t.integer :characters, null: false, default: 0
      t.boolean :success, null: false, default: true
      t.timestamps
    end
    add_index :audio_transcription_usages, [:account_id, :created_at]
  end
end
