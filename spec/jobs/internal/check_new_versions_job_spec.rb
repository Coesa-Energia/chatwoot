require 'rails_helper'

# COESA: o fork desligou a atualização via Hub. O job não chama o Hub nem grava a versão.
RSpec.describe Internal::CheckNewVersionsJob do
  subject(:job) { described_class.perform_now }

  it 'does not call the hub nor update the latest version in redis' do
    allow(Rails.env).to receive(:production?).and_return(true)
    allow(ChatwootHub).to receive(:sync_with_hub)
    Redis::Alfred.delete(Redis::Alfred::LATEST_CHATWOOT_VERSION)

    job

    expect(ChatwootHub).not_to have_received(:sync_with_hub)
    expect(Redis::Alfred.get(Redis::Alfred::LATEST_CHATWOOT_VERSION)).to be_nil
  end

  it 'accepts the refresh_billing option used by Super Admin > Settings and reports success' do
    expect(described_class.perform_now(refresh_billing: true)).to be_present
  end
end
