# TODO: lets use HTTParty instead of RestClient
class ChatwootHub
  DEFAULT_BASE_URL = 'https://hub.2.chatwoot.com'.freeze

  def self.base_url
    DEFAULT_BASE_URL
  end

  def self.ping_url
    "#{base_url}/ping"
  end

  def self.registration_url
    "#{base_url}/instances"
  end

  def self.push_notification_url
    "#{base_url}/send_push"
  end

  def self.events_url
    "#{base_url}/events"
  end

  def self.billing_base_url
    "#{base_url}/billing"
  end

  def self.installation_identifier
    identifier = InstallationConfig.find_by(name: 'INSTALLATION_IDENTIFIER')&.value
    identifier ||= InstallationConfig.create!(name: 'INSTALLATION_IDENTIFIER', value: SecureRandom.uuid).value
    identifier
  end

  def self.billing_url
    "#{billing_base_url}?installation_identifier=#{installation_identifier}"
  end

  def self.pricing_plan
    # COESA FORK: instalação própria sempre enterprise (tudo free, sem trava de plano).
    'enterprise'
  end

  def self.pricing_plan_quantity
    # COESA FORK: quantidade fixa alta para nunca travar por licença.
    9999
  end

  def self.support_config
    # COESA FORK: sem inbox de suporte do Chatwoot. Retorno fixo vazio.
    {
      support_website_token: nil,
      support_script_url: nil,
      support_identifier_hash: nil
    }
  end

  def self.instance_config
    {
      installation_identifier: installation_identifier,
      installation_version: Chatwoot.config[:version],
      installation_host: URI.parse(ENV.fetch('FRONTEND_URL', '')).host,
      installation_env: ENV.fetch('INSTALLATION_ENV', ''),
      edition: ENV.fetch('CW_EDITION', '')
    }
  end

  def self.instance_metrics
    {
      accounts_count: fetch_count(Account),
      users_count: fetch_count(User),
      inboxes_count: fetch_count(Inbox),
      conversations_count: fetch_count(Conversation),
      incoming_messages_count: fetch_count(Message.incoming),
      outgoing_messages_count: fetch_count(Message.outgoing),
      additional_information: {}
    }
  end

  def self.fetch_count(model)
    model.last&.id || 0
  end

  def self.sync_with_hub
    # COESA FORK: sem chamada externa. Retorno fixo com a versão local.
    { 'version' => Chatwoot.config[:version], 'plan' => 'enterprise', 'plan_quantity' => 9999 }
  end

  def self.register_instance(_company_name, _owner_name, _owner_email)
    # COESA FORK: registro externo desligado. Retorno fixo de sucesso local.
    true
  end

  def self.send_push(_fcm_options)
    # COESA FORK: relay via Hub desligado. Push sai só pelo Firebase próprio configurado na instalação.
    Rails.logger.info('COESA: push via Hub ignorado (relay desligado)')
    nil
  end

  def self.send_push_with_response(_fcm_options)
    # COESA FORK: relay via Hub desligado. Retorno fixo para o diagnóstico não quebrar.
    nil
  end

  def self.emit_event(_event_name, _event_data)
    # COESA FORK: telemetria externa desligada. Retorno fixo de sucesso.
    true
  end
end

ChatwootHub.singleton_class.prepend_mod_with('ChatwootHub')
