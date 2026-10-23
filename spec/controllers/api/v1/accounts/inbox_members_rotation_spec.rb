require 'rails_helper'

RSpec.describe 'Inbox members rotation', type: :request do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:seller) { create(:user, account: account, role: :agent) }
  let(:support) { create(:user, account: account, role: :agent) }
  let(:url) { "/api/v1/accounts/#{account.id}/inbox_members" }

  it 'puts every new member in the rotation by default' do
    post url, params: { inbox_id: inbox.id, user_ids: [seller.id, support.id] }, headers: admin.create_new_auth_token, as: :json

    expect(response.parsed_body['payload'].pluck('in_rotation')).to eq([true, true])
  end

  it 'adds members that stay out of the rotation' do
    post url, params: { inbox_id: inbox.id, user_ids: [seller.id, support.id], rotation_user_ids: [seller.id] },
              headers: admin.create_new_auth_token, as: :json

    flags = response.parsed_body['payload'].to_h { |member| [member['id'], member['in_rotation']] }
    expect(flags).to eq(seller.id => true, support.id => false)
  end

  it 'changes the rotation of existing members and can bring them back' do
    inbox.add_members([seller.id, support.id])

    patch url, params: { inbox_id: inbox.id, user_ids: [seller.id, support.id], rotation_user_ids: [seller.id] },
               headers: admin.create_new_auth_token, as: :json
    expect(InboxMember.find_by(inbox: inbox, user: support).in_rotation).to be(false)

    patch url, params: { inbox_id: inbox.id, user_ids: [seller.id, support.id], rotation_user_ids: [seller.id, support.id] },
               headers: admin.create_new_auth_token, as: :json
    expect(InboxMember.find_by(inbox: inbox, user: support).in_rotation).to be(true)
  end

  it 'leaves the rotation untouched when the param is not sent' do
    inbox.add_members([support.id])
    InboxMember.find_by(inbox: inbox, user: support).update!(in_rotation: false)

    patch url, params: { inbox_id: inbox.id, user_ids: [support.id] }, headers: admin.create_new_auth_token, as: :json

    expect(InboxMember.find_by(inbox: inbox, user: support).in_rotation).to be(false)
  end

  it 'does not let agents change the rotation' do
    inbox.add_members([seller.id])

    patch url, params: { inbox_id: inbox.id, user_ids: [seller.id], rotation_user_ids: [] }, headers: seller.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unauthorized)
    expect(InboxMember.find_by(inbox: inbox, user: seller).in_rotation).to be(true)
  end
end
