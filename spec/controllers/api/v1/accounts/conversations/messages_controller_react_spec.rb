require 'rails_helper'

# Agents react to WhatsApp messages with an emoji.
RSpec.describe 'Conversation message reactions API', type: :request do
  let!(:account) { create(:account) }
  let(:channel) { create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false) }
  let(:inbox) { channel.inbox }
  let(:contact_inbox) { create(:contact_inbox, inbox: inbox, source_id: '5511999990001') }
  let(:conversation) { create(:conversation, inbox: inbox, account: account, contact_inbox: contact_inbox, contact: contact_inbox.contact) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let!(:message) do
    create(:message, conversation: conversation, inbox: inbox, account: account, source_id: 'wamid.TARGET', message_type: :incoming)
  end
  let(:meta_url) { %r{graph\.facebook\.com/v13\.0/.+/messages} }
  let(:meta_ok) { { status: 200, body: { messages: [{ id: 'wamid.REACTION' }] }.to_json, headers: { 'Content-Type' => 'application/json' } } }

  before { create(:inbox_member, inbox: inbox, user: agent) }

  def react(emoji, target: message, user: agent)
    post "/api/v1/accounts/#{account.id}/conversations/#{target.conversation.display_id}/messages/#{target.id}/react",
         params: { emoji: emoji }, headers: user.create_new_auth_token, as: :json
  end

  it 'requires authentication' do
    post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/messages/#{message.id}/react", params: { emoji: '👍' }

    expect(response).to have_http_status(:unauthorized)
  end

  it 'sends the reaction to WhatsApp and stores it as the business reaction' do
    stub = stub_request(:post, meta_url)
           .with(body: hash_including(type: 'reaction', reaction: { message_id: 'wamid.TARGET', emoji: '👍' }))
           .to_return(meta_ok)

    react('👍')

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['reactions']).to eq('business' => '👍')
    expect(message.reload.content_attributes['reactions']).to eq('business' => '👍')
    expect(stub).to have_been_requested
  end

  it 'removes the reaction when the emoji is empty' do
    Whatsapp::MessageReactions.new(message: message).set('business', '👍')
    stub = stub_request(:post, meta_url).with(body: hash_including(reaction: { message_id: 'wamid.TARGET', emoji: '' })).to_return(meta_ok)

    react('')

    expect(response).to have_http_status(:success)
    expect(message.reload.content_attributes).not_to have_key('reactions')
    expect(stub).to have_been_requested
  end

  it 'keeps the customer reaction untouched' do
    Whatsapp::MessageReactions.new(message: message).set('contact', '❤️')
    stub_request(:post, meta_url).to_return(meta_ok)

    react('👍')

    expect(message.reload.content_attributes['reactions']).to eq('contact' => '❤️', 'business' => '👍')
  end

  it 'shows the error from WhatsApp and does not store the reaction' do
    stub_request(:post, meta_url).to_return(status: 400, body: { error: { message: 'Re-engagement message', code: 131_047 } }.to_json,
                                            headers: { 'Content-Type' => 'application/json' })

    react('👍')

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['error']).to eq('Re-engagement message')
    expect(message.reload.content_attributes).not_to have_key('reactions')
  end

  it 'refuses when the 24 hour window is closed' do
    allow_any_instance_of(Conversation).to receive(:can_reply?).and_return(false) # rubocop:disable RSpec/AnyInstance

    react('👍')

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['error']).to eq(I18n.t('errors.whatsapp.message_outside_messaging_window'))
  end

  it 'refuses an emoji field that is not a single emoji-sized value' do
    react('x' * 40)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['error']).to eq(I18n.t('errors.whatsapp.reaction_invalid'))
  end

  it 'refuses private notes' do
    note = create(:message, conversation: conversation, inbox: inbox, account: account,
                            source_id: 'wamid.NOTE', private: true, message_type: :outgoing)

    react('👍', target: note)

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'refuses messages that have no WhatsApp id yet' do
    unsent = create(:message, conversation: conversation, inbox: inbox, account: account, source_id: nil, message_type: :outgoing)

    react('👍', target: unsent)

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'refuses channels other than WhatsApp Cloud' do
    dialog = create(:channel_whatsapp, account: account, provider: 'default', sync_templates: false, validate_provider_config: false)
    dialog_conversation = create(:conversation, inbox: dialog.inbox, account: account)
    create(:inbox_member, inbox: dialog.inbox, user: agent)
    target = create(:message, conversation: dialog_conversation, inbox: dialog.inbox, account: account, source_id: 'wamid.X')

    react('👍', target: target)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['error']).to eq(I18n.t('errors.whatsapp.reactions_unsupported'))
  end

  it 'refuses agents without access to the inbox' do
    outsider = create(:user, account: account, role: :agent)

    react('👍', user: outsider)

    expect(response).to have_http_status(:unauthorized)
  end
end
