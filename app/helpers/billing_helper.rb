module BillingHelper
  private

  def agents(account)
    account.users.count
  end
end
