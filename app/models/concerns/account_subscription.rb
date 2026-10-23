# Subscription data the SaaS operator manages from SuperAdmin: plan name, trial end, paid-until date and
# free-form billing notes. Kept in `custom_attributes` under `saas_*` keys so they never collide with the
# keys other billing integrations use (plan_name, subscription_status, ...).
#
# An account without any end date has no expiry, so existing accounts keep working untouched.
module AccountSubscription
  extend ActiveSupport::Concern

  DATE_FORMAT = /\A\d{4}-\d{2}-\d{2}\z/
  # Postgres expression for the date the account stops being covered: the paid-until date wins over the trial end.
  # Only well-formed dates are cast, so a stray value can never break a query.
  ENDS_ON_SQL = <<~SQL.squish.freeze
    (CASE WHEN COALESCE(NULLIF(accounts.custom_attributes->>'saas_paid_until', ''), NULLIF(accounts.custom_attributes->>'saas_trial_ends_at', ''))
               ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
          THEN COALESCE(NULLIF(accounts.custom_attributes->>'saas_paid_until', ''), NULLIF(accounts.custom_attributes->>'saas_trial_ends_at', ''))::date
     END)
  SQL

  included do
    # Active accounts whose coverage ended more than `grace_days` days ago.
    scope :subscription_expired, lambda { |grace_days: 0, today: Time.zone.today|
      active.where("#{ENDS_ON_SQL} < ?", today - grace_days)
    }
    # Active accounts whose coverage ends within the next `days` days (today included).
    scope :subscription_expiring, lambda { |days: 7, today: Time.zone.today|
      active.where("#{ENDS_ON_SQL} BETWEEN ? AND ?", today, today + days)
    }
  end

  def saas_plan
    subscription_attribute('saas_plan')
  end

  def saas_plan=(value)
    write_subscription_attribute('saas_plan', value.to_s.strip.presence)
  end

  def saas_notes
    subscription_attribute('saas_notes')
  end

  def saas_notes=(value)
    write_subscription_attribute('saas_notes', value.to_s.strip.presence)
  end

  def saas_trial_ends_at
    subscription_date('saas_trial_ends_at')
  end

  def saas_trial_ends_at=(value)
    write_subscription_attribute('saas_trial_ends_at', normalize_subscription_date(value))
  end

  def saas_paid_until
    subscription_date('saas_paid_until')
  end

  def saas_paid_until=(value)
    write_subscription_attribute('saas_paid_until', normalize_subscription_date(value))
  end

  # The date coverage ends: paid-until if set, otherwise the trial end. nil means no expiry.
  def subscription_ends_on
    saas_paid_until || saas_trial_ends_at
  end

  def subscription_expired?(grace_days: 0, today: Time.zone.today)
    ends_on = subscription_ends_on
    ends_on.present? && ends_on < today - grace_days
  end

  private

  def subscription_attribute(key)
    (custom_attributes || {})[key].presence
  end

  def subscription_date(key)
    value = subscription_attribute(key)
    value.to_s.match?(DATE_FORMAT) ? Date.iso8601(value) : nil
  rescue Date::Error
    nil
  end

  def write_subscription_attribute(key, value)
    attributes = (custom_attributes || {}).dup
    value.nil? ? attributes.delete(key) : attributes[key] = value
    self.custom_attributes = attributes
  end

  def normalize_subscription_date(value)
    return nil if value.blank?

    date = value.respond_to?(:to_date) ? value.to_date : Date.iso8601(value.to_s)
    date.iso8601
  rescue Date::Error
    nil
  end
end
