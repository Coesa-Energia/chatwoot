require 'rails_helper'

RSpec.describe Accounts::SuspendExpiredSubscriptionsService do
  let(:today) { Date.new(2026, 10, 12) }
  let!(:expired) { create(:account, custom_attributes: { 'saas_paid_until' => '2026-10-01' }) }
  let!(:in_grace) { create(:account, custom_attributes: { 'saas_paid_until' => '2026-10-10' }) }
  let!(:valid) { create(:account, custom_attributes: { 'saas_paid_until' => '2027-01-01' }) }
  let!(:no_date) { create(:account) }

  it 'suspends only the accounts past the grace period and returns how many' do
    count = described_class.new(grace_days: 3, today: today).perform

    expect(count).to eq(1)
    expect(expired.reload).to be_suspended
    expect([in_grace, valid, no_date].map { |account| account.reload.status }).to all(eq('active'))
  end

  it 'records a non-payment suspension in the history' do
    described_class.new(grace_days: 3, today: today).perform

    event = expired.reload.suspension_history.last
    expect(event).to include('category' => 'non_payment')
    expect(event['reason']).to include('2026-10-01')
    expect(event['suspended_at']).to be_present
  end

  it 'keeps earlier suspension history' do
    expired.update!(internal_attributes: { 'suspensions' => [{ 'category' => 'spam', 'reason' => 'old' }] })

    described_class.new(grace_days: 3, today: today).perform

    expect(expired.reload.suspension_history.pluck('category')).to eq(%w[spam non_payment])
  end

  it 'does nothing twice' do
    described_class.new(grace_days: 3, today: today).perform

    expect(described_class.new(grace_days: 3, today: today).perform).to eq(0)
    expect(expired.reload.suspension_history.size).to eq(1)
  end

  it 'reads the grace period from SAAS_GRACE_DAYS' do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('SAAS_GRACE_DAYS', 3).and_return('15')

    expect(described_class.new(today: today).perform).to eq(0)
  end
end
