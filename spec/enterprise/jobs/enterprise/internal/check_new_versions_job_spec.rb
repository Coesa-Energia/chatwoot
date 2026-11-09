require 'rails_helper'

# COESA: o fork desligou a sincronização com o Hub. O job não grava plano, suporte nem
# status de assinatura, não reconcilia features premium e nunca avisa pagamento atrasado.
RSpec.describe Internal::CheckNewVersionsJob do
  subject(:job) { described_class.perform_now }

  before do
    allow(Rails.env).to receive(:production?).and_return(true)
    allow(Internal::ReconcilePlanConfigService).to receive(:new)
    allow(ChatwootHub).to receive(:sync_with_hub).and_return({ 'version' => '1.2.3', 'plan' => 'community', 'subscription_status' => 'past_due' })
  end

  it 'does not overwrite the plan or the support settings' do
    job

    expect(InstallationConfig.find_by(name: 'INSTALLATION_PRICING_PLAN')).to be_nil
    expect(InstallationConfig.find_by(name: 'CHATWOOT_SUPPORT_WEBSITE_TOKEN')).to be_nil
  end

  it 'never reconciles premium features' do
    job

    expect(Internal::ReconcilePlanConfigService).not_to have_received(:new)
  end

  it 'never stores a subscription status nor notifies accounts' do
    account = create(:account)

    expect { job }.not_to have_broadcasted_to("account_#{account.id}")
    expect(InstallationConfig.find_by(name: 'INSTALLATION_SUBSCRIPTION_STATUS')).to be_nil
    expect(ChatwootHub.subscription_status).to be_nil
  end

  it 'reports success for the Super Admin refresh button' do
    expect(described_class.perform_now(refresh_billing: true)).to be_present
  end
end
