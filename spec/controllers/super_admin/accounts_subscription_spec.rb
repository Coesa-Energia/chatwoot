require 'rails_helper'

RSpec.describe 'Super Admin account subscription', type: :request do
  let!(:super_admin) { create(:super_admin) }
  let!(:account) { create(:account, custom_attributes: { 'plan_name' => 'Business' }) }

  before { sign_in(super_admin, scope: :super_admin) }

  def save_subscription(attributes)
    patch "/super_admin/accounts/#{account.id}/subscription", params: { account: attributes }
  end

  it 'saves the plan, dates and notes' do
    save_subscription(saas_plan: 'Pro', saas_trial_ends_at: '2026-10-20', saas_paid_until: '2026-12-01', saas_notes: 'Pix todo dia 1')

    expect(response).to redirect_to("/super_admin/accounts/#{account.id}")
    expect(account.reload.custom_attributes).to include('plan_name' => 'Business', 'saas_plan' => 'Pro',
                                                        'saas_paid_until' => '2026-12-01', 'saas_notes' => 'Pix todo dia 1')
  end

  it 'ignores other account attributes' do
    save_subscription(saas_plan: 'Pro', name: 'Hacked', status: 'suspended')

    expect(account.reload).to have_attributes(name: account.name, status: 'active')
  end

  it 'reactivates an account suspended for non-payment once the paid-until date is in the future' do
    account.update!(status: :suspended, saas_paid_until: '2026-01-01',
                    internal_attributes: { 'suspensions' => [{ 'category' => 'non_payment', 'reason' => 'late' }] })

    save_subscription(saas_paid_until: 30.days.from_now.to_date.iso8601)

    expect(account.reload).to be_active
  end

  it 'keeps accounts suspended for other reasons suspended' do
    account.update!(status: :suspended, internal_attributes: { 'suspensions' => [{ 'category' => 'spam', 'reason' => 'bad' }] })

    save_subscription(saas_paid_until: 30.days.from_now.to_date.iso8601)

    expect(account.reload).to be_suspended
  end

  it 'does not reactivate while the date is still in the past' do
    account.update!(status: :suspended, internal_attributes: { 'suspensions' => [{ 'category' => 'non_payment', 'reason' => 'late' }] })

    save_subscription(saas_paid_until: 3.days.ago.to_date.iso8601)

    expect(account.reload).to be_suspended
  end

  it 'requires a super admin' do
    sign_out(:super_admin)

    save_subscription(saas_plan: 'Pro')

    expect(response).to have_http_status(:redirect)
    expect(account.reload.saas_plan).to be_nil
  end
end
