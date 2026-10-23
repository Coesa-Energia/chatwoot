# Suspends active accounts whose SaaS subscription (trial or paid-until date, see AccountSubscription) ended
# more than `grace_days` days ago. The suspension is recorded in the account's suspension history so the
# SuperAdmin shows it as a non-payment suspension. Accounts without an end date are never touched.
class Accounts::SuspendExpiredSubscriptionsService
  DEFAULT_GRACE_DAYS = 3

  pattr_initialize [:grace_days, :today]

  def perform
    Account.subscription_expired(grace_days: grace, today: current_day).find_each.count { |account| suspend(account) }
  end

  private

  def grace
    grace_days || ENV.fetch('SAAS_GRACE_DAYS', DEFAULT_GRACE_DAYS).to_i
  end

  def current_day
    today || Time.zone.today
  end

  def suspend(account)
    event = {
      'category' => 'non_payment',
      'reason' => I18n.t('super_admin.account_suspension.automatic_reason', date: account.subscription_ends_on.iso8601),
      'suspended_at' => Time.current.iso8601
    }
    account.with_lock do
      next false unless account.active?

      account.internal_attributes = account.internal_attributes.merge('suspensions' => account.suspension_history + [event])
      account.update!(status: :suspended)
    end
  end
end
