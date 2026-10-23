require 'rails_helper'

RSpec.describe AccountBranding do
  describe '.installation_brand_account' do
    let!(:without_logo) { create(:account) }
    let!(:first_with_logo) { create(:account) }
    let!(:second_with_logo) { create(:account) }

    before do
      [first_with_logo, second_with_logo].each do |account|
        account.logo.attach(io: Rails.root.join('spec/assets/avatar.png').open, filename: 'avatar.png', content_type: 'image/png')
      end
    end

    it 'returns the oldest account that has a logo' do
      expect(Account.installation_brand_account).to eq(first_with_logo)
      expect(Account.installation_brand_account).not_to eq(without_logo)
    end
  end
end
