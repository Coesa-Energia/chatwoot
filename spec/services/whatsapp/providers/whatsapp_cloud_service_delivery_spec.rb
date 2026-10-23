require 'rails_helper'

# Delivery behaviour of the Cloud provider: several attachments per message, Meta rate limits,
# connection failures and ambiguous timeouts.
describe Whatsapp::Providers::WhatsappCloudService do
  subject(:service) { described_class.new(whatsapp_channel: whatsapp_channel) }

  let(:whatsapp_channel) do
    create(:channel_whatsapp, provider: 'whatsapp_cloud', validate_provider_config: false, sync_templates: false)
  end
  let(:conversation) { create(:conversation, inbox: whatsapp_channel.inbox) }
  let(:message) { create(:message, conversation: conversation, message_type: :outgoing, content: 'legenda', inbox: whatsapp_channel.inbox) }
  let(:headers) { { 'Content-Type' => 'application/json' } }
  let(:messages_url) { 'https://graph.facebook.com/v22.0/123456789/messages' }
  let(:media_messages_url) { 'https://graph.facebook.com/v22.0/123456789/messages' }
  let(:ok_response) { { status: 200, body: { messages: [{ id: 'wamid.first' }] }.to_json, headers: headers } }

  def meta_error(code, status: 400)
    { status: status, body: { error: { message: 'meta error', code: code } }.to_json, headers: headers }
  end

  def attach_image(target_message, name)
    attachment = target_message.attachments.new(account_id: target_message.account_id, file_type: :image)
    attachment.file.attach(io: Rails.root.join('spec/assets/avatar.png').open, filename: name, content_type: 'image/png')
    attachment.save!
  end

  before do
    stub_request(:get, 'https://graph.facebook.com/v22.0/123456789/message_templates?access_token=test_key')
    stub_request(:post, 'https://graph.facebook.com/v22.0/123456789/media')
      .to_return(status: 200, body: { id: 'uploaded_media_id' }.to_json, headers: headers)
  end

  describe 'messages with several attachments' do
    before do
      attach_image(message, 'a.png')
      attach_image(message, 'b.png')
    end

    it 'sends every attachment, with the caption only on the first, and returns the first id' do
      sent_images = []
      stub_request(:post, media_messages_url).to_return do |request|
        sent_images << JSON.parse(request.body).fetch('image')
        { status: 200, body: { messages: [{ id: "wamid.#{sent_images.size}" }] }.to_json, headers: headers }
      end

      expect(service.send_message('+123456789', message)).to eq('wamid.1')

      expect(sent_images.size).to eq(2)
      expect(sent_images.first['caption']).to eq('legenda')
      expect(sent_images.last).not_to have_key('caption')
    end

    it 'stops and records the failure when a later attachment fails, keeping the first id' do
      stub_request(:post, media_messages_url).to_return(ok_response, meta_error(131_000))

      expect(service.send_message('+123456789', message)).to eq('wamid.first')
      expect(message.reload.status).to eq('failed')
      expect(message.external_error).to eq('meta error')
    end

    it 'does not raise a retryable error for a later attachment, to avoid resending the first one' do
      stub_request(:post, media_messages_url).to_return(ok_response, meta_error(130_429))

      expect { service.send_message('+123456789', message) }.not_to raise_error
      expect(message.reload.status).to eq('failed')
    end
  end

  describe 'Meta rate limits' do
    [130_429, 131_056, 80_007].each do |code|
      it "raises a retryable error for Meta error #{code} and does not mark the message failed" do
        stub_request(:post, messages_url).to_return(meta_error(code))

        expect { service.send_message('+123456789', message) }.to raise_error(CustomExceptions::WhatsappRetryableError)
        expect(message.reload.status).not_to eq('failed')
      end
    end

    it 'raises a retryable error for an HTTP 429 response' do
      stub_request(:post, messages_url).to_return(status: 429, body: '{}', headers: headers)

      expect { service.send_message('+123456789', message) }.to raise_error(CustomExceptions::WhatsappRetryableError)
    end

    it 'still marks the message failed for non rate limit errors' do
      stub_request(:post, messages_url).to_return(meta_error(131_047))

      expect(service.send_message('+123456789', message)).to be_nil
      expect(message.reload.status).to eq('failed')
    end

    it 'does not raise for template sends without a message (campaigns)' do
      stub_request(:post, messages_url).to_return(meta_error(130_429))

      template_info = { name: 'promo', namespace: nil, lang_code: 'pt_BR', parameters: [] }
      expect(service.send_template('+123456789', template_info, nil)).to be_nil
    end
  end

  describe 'network failures' do
    it 'raises a retryable error when the connection is refused (the request never reached Meta)' do
      stub_request(:post, messages_url).to_raise(Errno::ECONNREFUSED)

      expect { service.send_message('+123456789', message) }.to raise_error(CustomExceptions::WhatsappRetryableError)
    end

    it 'raises a retryable error on a connect timeout' do
      stub_request(:post, messages_url).to_raise(Net::OpenTimeout)

      expect { service.send_message('+123456789', message) }.to raise_error(CustomExceptions::WhatsappRetryableError)
    end

    it 'marks the message failed, without retrying, on a read timeout (delivery unconfirmed)' do
      stub_request(:post, messages_url).to_raise(Net::ReadTimeout)

      expect(service.send_message('+123456789', message)).to be_nil
      expect(message.reload.status).to eq('failed')
      expect(message.external_error).to eq(I18n.t('errors.whatsapp.send_unconfirmed'))
    end
  end
end
