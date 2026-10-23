require 'rails_helper'

# Administrators are warned when a WhatsApp Cloud channel has no Meta app secret (its webhooks would all be
# rejected). Agents must not receive that flag, nor the 360dialog webhook token.
RSpec.describe 'Inbox webhook secret flag', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }

  before do
    InstallationConfig.where(name: 'WHATSAPP_APP_SECRET').delete_all
    GlobalConfig.clear_cache
  end

  def show_inbox(inbox, user)
    get "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}", headers: user.create_new_auth_token, as: :json
    response.parsed_body
  end

  describe 'WhatsApp Cloud channel without an app secret' do
    let(:channel) { create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false) }

    before do
      channel.update!(provider_config: channel.provider_config.except('app_secret', 'app_secret_key', 'api_secret', 'client_secret', 'source'))
      create(:inbox_member, user: agent, inbox: channel.inbox)
    end

    it 'flags the missing secret for administrators' do
      expect(show_inbox(channel.inbox, admin)['webhook_secret_missing']).to be(true)
    end

    it 'does not expose the flag to agents' do
      expect(show_inbox(channel.inbox, agent)).not_to have_key('webhook_secret_missing')
    end

    it 'clears the flag when the global WHATSAPP_APP_SECRET is configured' do
      with_modified_env WHATSAPP_APP_SECRET: 'meta-app-secret' do
        expect(show_inbox(channel.inbox, admin)['webhook_secret_missing']).to be(false)
      end
    end

    it 'clears the flag when the channel has its own app secret' do
      channel.update!(provider_config: channel.provider_config.merge('app_secret' => 'channel-secret'))

      expect(show_inbox(channel.inbox, admin)['webhook_secret_missing']).to be(false)
    end
  end

  describe 'channels that do not need a Meta app secret' do
    it 'does not flag a 360dialog channel' do
      channel = create(:channel_whatsapp, account: account, provider: 'default', sync_templates: false, validate_provider_config: false)

      expect(show_inbox(channel.inbox, admin)['webhook_secret_missing']).to be(false)
    end

    it 'does not add the flag to non-WhatsApp inboxes' do
      inbox = create(:inbox, account: account)

      expect(show_inbox(inbox, admin)).not_to have_key('webhook_secret_missing')
    end
  end

  describe '360dialog webhook token exposure' do
    let(:channel) { create(:channel_whatsapp, account: account, provider: 'default', sync_templates: false, validate_provider_config: false) }

    before { create(:inbox_member, user: agent, inbox: channel.inbox) }

    it 'includes the token in the webhook URL for administrators' do
      expect(show_inbox(channel.inbox, admin)['callback_webhook_url']).to include("token=#{channel.provider_config['webhook_secret']}")
    end

    it 'does not include the token for agents' do
      expect(show_inbox(channel.inbox, agent)['callback_webhook_url']).not_to include('token=')
    end
  end
end
