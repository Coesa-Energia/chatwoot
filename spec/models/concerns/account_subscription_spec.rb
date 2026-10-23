require 'rails_helper'

RSpec.describe AccountSubscription do
  let(:account) { create(:account) }
  let(:today) { Date.new(2026, 10, 12) }

  describe 'attributes' do
    it 'stores the plan, dates and notes under saas_* keys of custom_attributes' do
      account.update!(saas_plan: ' Pro ', saas_trial_ends_at: '2026-10-20', saas_paid_until: Date.new(2026, 11, 5), saas_notes: 'Pix mensal')
      account.reload

      expect(account.custom_attributes).to include('saas_plan' => 'Pro', 'saas_trial_ends_at' => '2026-10-20',
                                                   'saas_paid_until' => '2026-11-05', 'saas_notes' => 'Pix mensal')
      expect(account.saas_paid_until).to eq(Date.new(2026, 11, 5))
    end

    it 'keeps the keys other billing integrations use' do
      account.update!(custom_attributes: { 'plan_name' => 'Business' })
      account.update!(saas_plan: 'Pro')

      expect(account.reload.custom_attributes).to include('plan_name' => 'Business', 'saas_plan' => 'Pro')
    end

    it 'removes a value when it is cleared and ignores invalid dates' do
      account.update!(saas_plan: 'Pro', saas_paid_until: '2026-11-05')
      account.update!(saas_plan: '', saas_paid_until: 'not a date')

      expect(account.reload.custom_attributes.keys).not_to include('saas_plan', 'saas_paid_until')
    end
  end

  describe '#subscription_ends_on and #subscription_expired?' do
    it 'has no expiry without dates' do
      expect(account.subscription_ends_on).to be_nil
      expect(account.subscription_expired?(today: today)).to be(false)
    end

    it 'uses the paid-until date over the trial end' do
      account.update!(saas_trial_ends_at: '2026-10-01', saas_paid_until: '2026-11-01')

      expect(account.subscription_ends_on).to eq(Date.new(2026, 11, 1))
      expect(account.subscription_expired?(today: today)).to be(false)
    end

    it 'falls back to the trial end and honours the grace period' do
      account.update!(saas_trial_ends_at: '2026-10-10')

      expect(account.subscription_expired?(today: today)).to be(true)
      expect(account.subscription_expired?(grace_days: 2, today: today)).to be(false)
      expect(account.subscription_expired?(grace_days: 1, today: today)).to be(true)
    end
  end

  describe 'scopes' do
    let!(:expired) { create(:account, name: 'expired', custom_attributes: { 'saas_paid_until' => '2026-10-01' }) }
    let!(:expiring) { create(:account, name: 'expiring', custom_attributes: { 'saas_trial_ends_at' => '2026-10-15' }) }

    before do
      create(:account, name: 'valid', custom_attributes: { 'saas_paid_until' => '2027-01-01' })
      create(:account, name: 'no date')
      create(:account, name: 'broken', custom_attributes: { 'saas_paid_until' => 'garbage' })
      create(:account, name: 'suspended', status: :suspended, custom_attributes: { 'saas_paid_until' => '2026-01-01' })
    end

    it 'finds active accounts whose coverage ended' do
      expect(Account.subscription_expired(today: today)).to contain_exactly(expired)
    end

    it 'applies the grace period' do
      expect(Account.subscription_expired(grace_days: 15, today: today)).to be_empty
    end

    it 'finds active accounts that expire soon' do
      expect(Account.subscription_expiring(days: 7, today: today)).to contain_exactly(expiring)
    end
  end
end
