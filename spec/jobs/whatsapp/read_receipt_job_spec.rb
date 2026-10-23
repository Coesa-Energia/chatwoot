require 'rails_helper'

RSpec.describe Whatsapp::ReadReceiptJob do
  it 'runs the read receipt service for the conversation' do
    conversation = create(:conversation)
    service = instance_double(Whatsapp::ReadReceiptService, perform: nil)
    allow(Whatsapp::ReadReceiptService).to receive(:new).with(conversation: conversation).and_return(service)

    described_class.perform_now(conversation.id)

    expect(service).to have_received(:perform)
  end

  it 'ignores conversations that no longer exist' do
    expect { described_class.perform_now(0) }.not_to raise_error
  end

  it 'runs on the medium queue' do
    expect { described_class.perform_later(1) }.to have_enqueued_job(described_class).on_queue('medium')
  end
end
