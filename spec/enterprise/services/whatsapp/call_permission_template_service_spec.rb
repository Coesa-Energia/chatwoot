require 'rails_helper'

describe Whatsapp::CallPermissionTemplateService do
  subject(:service) { described_class.new(channel: channel) }

  let(:channel) { create(:channel_whatsapp, provider: 'whatsapp_cloud', validate_provider_config: false, sync_templates: false) }
  let(:provider_service) { instance_double(Whatsapp::Providers::WhatsappCloudService) }
  let(:meta_template) do
    { 'name' => 'meu_modelo', 'language' => 'pt_BR', 'status' => 'APPROVED', 'category' => 'MARKETING',
      'components' => [{ 'type' => 'BODY', 'text' => 'Oi!' }, { 'type' => 'call_permission_request' }] }
  end

  before { allow(Whatsapp::Providers::WhatsappCloudService).to receive(:new).and_return(provider_service) }

  describe '#state' do
    it 'offers the default text before anything exists and does not call Meta' do
      expect(provider_service).not_to receive(:find_message_template)

      expect(service.state).to include(created: false, status: nil, body: service.state[:default_body])
    end
  end

  describe '#approved?' do
    it 'is false and silent while nothing was created' do
      expect(provider_service).not_to receive(:find_message_template)

      expect(service.approved?).to be false
    end

    it 'trusts a stored APPROVED status' do
      channel.update!(provider_config: channel.provider_config.merge('call_permission_template' => { 'status' => 'APPROVED' }))

      expect(service.approved?).to be true
    end
  end

  describe '#create' do
    it 'sends the edited text to Meta and stores it as pending' do
      allow(provider_service).to receive(:find_message_template).and_return(nil)
      allow(provider_service).to receive(:create_call_permission_template).and_return('id' => '1')

      result = service.create(name: 'novo_modelo', body: 'Texto editado')

      expect(result).to include(name: 'novo_modelo', status: 'PENDING', body: 'Texto editado', category: 'UTILITY')
      expect(provider_service).to have_received(:create_call_permission_template)
        .with(name: 'novo_modelo', language: 'pt_BR', body: 'Texto editado', category: 'UTILITY')
      expect(channel.reload.provider_config.dig('call_permission_template', 'body')).to eq('Texto editado')
    end

    it 'uses the default name and text when none are given' do
      allow(provider_service).to receive(:find_message_template).and_return(nil)
      allow(provider_service).to receive(:create_call_permission_template).and_return('id' => '1')

      expect(service.create).to include(name: described_class::TEMPLATE_NAME, body: service.state[:default_body])
    end

    it 'adopts a call-permission template that already exists on Meta instead of creating another' do
      allow(provider_service).to receive(:find_message_template).with('meu_modelo').and_return(meta_template)
      expect(provider_service).not_to receive(:create_call_permission_template)

      expect(service.create(name: 'meu_modelo')).to include(name: 'meu_modelo', status: 'APPROVED', body: 'Oi!', category: 'MARKETING')
    end

    it 'refuses an existing template that is not a call-permission one' do
      allow(provider_service).to receive(:find_message_template)
        .and_return(meta_template.merge('components' => [{ 'type' => 'BODY', 'text' => 'Oi' }]))

      expect { service.create(name: 'meu_modelo') }.to raise_error(described_class::InvalidTemplate, /meu_modelo/)
    end

    it 'rejects names and variables Meta would refuse' do
      expect { service.create(name: 'Nome Ruim') }.to raise_error(described_class::InvalidTemplate)
      expect { service.create(body: 'Oi {{1}}') }.to raise_error(described_class::InvalidTemplate)
    end

    it 'keeps the category Meta assigned after review' do
      channel.update!(provider_config: channel.provider_config.merge('call_permission_template' => { 'name' => 'meu_modelo' }))
      allow(provider_service).to receive(:find_message_template).and_return(meta_template)

      expect(service.refresh[:category]).to eq('MARKETING')
    end
  end

  describe '#refresh' do
    it 'stores the status and rejection reason Meta reports' do
      channel.update!(provider_config: channel.provider_config.merge('call_permission_template' => { 'name' => 'meu_modelo' }))
      allow(provider_service).to receive(:find_message_template)
        .and_return(meta_template.merge('status' => 'REJECTED', 'rejected_reason' => 'INVALID_FORMAT'))

      expect(service.refresh).to include(status: 'REJECTED', rejected_reason: 'INVALID_FORMAT')
    end

    it 'flags a template that disappeared from Meta' do
      channel.update!(provider_config: channel.provider_config.merge(
        'call_permission_template' => { 'name' => 'meu_modelo', 'status' => 'APPROVED' }
      ))
      allow(provider_service).to receive(:find_message_template).and_return(nil)

      expect(service.refresh).to include(status: 'NOT_FOUND', created: false)
      expect(service.approved?).to be false
    end
  end
end
