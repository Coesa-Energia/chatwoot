class Internal::SuspendExpiredSubscriptionsJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Accounts::SuspendExpiredSubscriptionsService.new.perform
  end
end
