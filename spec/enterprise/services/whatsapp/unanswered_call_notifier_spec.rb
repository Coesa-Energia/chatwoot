require 'rails_helper'

describe Whatsapp::UnansweredCallNotifier do
  let(:account) { create(:account) }
  let(:channel) do
    create(:channel_whatsapp, provider: 'whatsapp_cloud', account: account, validate_provider_config: false, sync_templates: false)
  end
  let(:inbox) { channel.inbox }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:contact) { conversation.contact }

  before { allow(Conversations::ActivityMessageJob).to receive(:perform_later) }

  def make_call(status, created_at: Time.current, direction: :outgoing)
    create(:call, account: account, inbox: inbox, conversation: conversation, contact: contact, provider: :whatsapp,
                  direction: direction, status: status, provider_call_id: SecureRandom.hex(6), created_at: created_at)
  end

  def activity_content
    content = nil
    expect(Conversations::ActivityMessageJob).to have_received(:perform_later) { |_conversation, payload| content = payload[:content] }
    content
  end

  it 'posts the running count after an unanswered outgoing call' do
    make_call('no_answer', created_at: 2.minutes.ago)
    call = make_call('no_answer')

    described_class.new(call: call).perform

    expect(activity_content).to include('2 of 4')
  end

  it 'starts counting again after an answered call' do
    make_call('no_answer', created_at: 5.minutes.ago)
    make_call('completed', created_at: 3.minutes.ago)
    call = make_call('no_answer')

    described_class.new(call: call).perform

    expect(activity_content).to include('1 of 4')
  end

  it 'warns that the permission was removed on the fourth miss' do
    3.times { |i| make_call('no_answer', created_at: (10 - i).minutes.ago) }
    call = make_call('no_answer')

    described_class.new(call: call).perform

    expect(activity_content).to include('removed')
  end

  it 'ignores calls made before the permission was granted' do
    make_call('no_answer', created_at: 2.hours.ago)
    conversation.update!(additional_attributes: { 'call_permission_granted_at' => 1.hour.ago.iso8601 })
    call = make_call('no_answer')

    described_class.new(call: call).perform

    expect(activity_content).to include('1 of 4')
  end

  it 'does nothing for answered or incoming calls' do
    described_class.new(call: make_call('completed')).perform
    described_class.new(call: make_call('no_answer', direction: :incoming)).perform

    expect(Conversations::ActivityMessageJob).not_to have_received(:perform_later)
  end
end
