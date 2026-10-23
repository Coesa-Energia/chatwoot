require 'rails_helper'

RSpec.describe 'Account branding (logo and brand display)', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:png) { fixture_file_upload(Rails.root.join('spec/assets/avatar.png'), 'image/png') }
  let(:text_file) { fixture_file_upload(Rails.root.join('spec/assets/attachment.pdf'), 'application/pdf') }

  def update_account(params, user = admin)
    patch "/api/v1/accounts/#{account.id}", params: params, headers: user.create_new_auth_token
  end

  it 'uploads a logo and returns its url' do
    update_account(logo: png)

    expect(response).to have_http_status(:success)
    expect(account.reload.logo).to be_attached
    expect(response.parsed_body['logo_url']).to start_with('/rails/active_storage')
  end

  it 'rejects files that are not images' do
    update_account(logo: text_file)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(account.reload.logo).not_to be_attached
  end

  it 'removes the uploaded logo and the one found at signup' do
    account.update!(custom_attributes: { 'logo' => 'https://example.com/logo.png' })
    account.logo.attach(io: Rails.root.join('spec/assets/avatar.png').open, filename: 'avatar.png', content_type: 'image/png')

    update_account(remove_logo: true)

    expect(response).to have_http_status(:success)
    expect(account.reload.logo).not_to be_attached
    expect(response.parsed_body['logo_url']).to be_nil
  end

  it 'falls back to the logo found at signup' do
    account.update!(custom_attributes: { 'logo' => 'https://example.com/logo.png' })

    get "/api/v1/accounts/#{account.id}", headers: admin.create_new_auth_token

    expect(response.parsed_body['logo_url']).to eq('https://example.com/logo.png')
  end

  it 'defaults to logo above name and accepts the other layouts' do
    get "/api/v1/accounts/#{account.id}", headers: admin.create_new_auth_token
    expect(response.parsed_body['brand_display']).to eq('logo_name')

    update_account(brand_display: 'name')
    expect(response.parsed_body['brand_display']).to eq('name')
    expect(account.reload.brand_display).to eq('name')
  end

  it 'rejects an unknown layout' do
    update_account(brand_display: 'banner')

    expect(response).to have_http_status(:unprocessable_entity)
    expect(account.reload.brand_display).to eq('logo_name')
  end

  it 'does not let agents change the brand' do
    update_account({ brand_display: 'logo' }, agent)

    expect(response).to have_http_status(:unauthorized)
    expect(account.reload.brand_display).to eq('logo_name')
  end

  it 'uploads and removes the image shown when the sidebar is collapsed' do
    update_account(collapsed_logo: png)

    expect(response).to have_http_status(:success)
    expect(account.reload.collapsed_logo).to be_attached
    expect(response.parsed_body['collapsed_logo_url']).to start_with('/rails/active_storage')
    expect(response.parsed_body['logo_url']).to be_nil

    update_account(remove_collapsed_logo: true)

    expect(account.reload.collapsed_logo).not_to be_attached
    expect(response.parsed_body['collapsed_logo_url']).to be_nil
  end

  it 'rejects a collapsed image that is not an image' do
    update_account(collapsed_logo: text_file)

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'accepts the logo beside the name layout' do
    update_account(brand_display: 'logo_name_inline')

    expect(response.parsed_body['brand_display']).to eq('logo_name_inline')
  end

  it 'lets the administrator choose which image sits next to the name' do
    get "/api/v1/accounts/#{account.id}", headers: admin.create_new_auth_token
    expect(response.parsed_body['brand_text_image']).to eq('logo')

    update_account(brand_text_image: 'collapsed_logo')
    expect(response.parsed_body['brand_text_image']).to eq('collapsed_logo')

    update_account(brand_text_image: 'banner')
    expect(response).to have_http_status(:unprocessable_entity)
    expect(account.reload.brand_text_image).to eq('collapsed_logo')
  end
end
