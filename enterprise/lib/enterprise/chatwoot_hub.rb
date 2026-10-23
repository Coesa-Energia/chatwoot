module Enterprise::ChatwootHub
  ENTERPRISE_BASE_URL = 'https://hub.2.chatwoot.com'.freeze

  # COESA FORK: nenhuma chamada enterprise sai para o Hub. Falha rápido em localhost se algo escapar.
  def base_url
    'http://127.0.0.1:9'
  end
end
