require 'rails_helper'

RSpec.describe Internal::SuspendExpiredSubscriptionsJob do
  it 'runs the suspension service on the scheduled queue' do
    service = instance_double(Accounts::SuspendExpiredSubscriptionsService, perform: 0)
    allow(Accounts::SuspendExpiredSubscriptionsService).to receive(:new).and_return(service)

    described_class.perform_now

    expect(service).to have_received(:perform)
    expect(described_class.new.queue_name).to eq('scheduled_jobs')
  end
end
