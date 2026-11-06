require 'rails_helper'

# COESA: o fork removeu cobrança e assinatura. Do helper só ficou `agents`.
RSpec.describe BillingHelper do
  describe '#agents' do
    it 'counts the users of the account' do
      account = create(:account)
      create_list(:user, 2, account: account)
      expect(helper.send(:agents, account)).to eq(2)
    end
  end
end
