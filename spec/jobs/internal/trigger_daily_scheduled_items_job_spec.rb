require 'rails_helper'

RSpec.describe Internal::TriggerDailyScheduledItemsJob do
  subject(:perform_job) { described_class.perform_now }

  let(:installation_id) { 'test-installation-id' }
  let(:designated_minute) { Digest::MD5.hexdigest(installation_id).hex % 1440 }
  let(:scheduled_time) { Time.current.utc.beginning_of_day + designated_minute.minutes }
  let(:configured_job) { instance_double(ActiveJob::ConfiguredJob, perform_later: true) }

  before do
    allow(ChatwootHub).to receive(:installation_identifier).and_return(installation_id)
    allow(Internal::CheckNewVersionsJob).to receive(:set).and_return(configured_job)
  end

  it 'enqueues the job' do
    expect { described_class.perform_later }.to have_enqueued_job(described_class)
      .on_queue('scheduled_jobs')
  end

  # COESA: a verificação diária de versão foi desligada no fork.
  it 'does not schedule the version check, even in production' do
    allow(Rails.env).to receive(:production?).and_return(true)

    perform_job

    expect(Internal::CheckNewVersionsJob).not_to have_received(:set)
  end

  it 'does not schedule the version check outside production' do
    allow(Rails.env).to receive(:production?).and_return(false)

    perform_job

    expect(Internal::CheckNewVersionsJob).not_to have_received(:set)
  end
end
