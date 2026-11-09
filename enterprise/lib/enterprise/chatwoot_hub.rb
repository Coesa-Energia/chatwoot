module Enterprise::ChatwootHub
  ENTERPRISE_BASE_URL = 'https://hub.2.chatwoot.com'.freeze

  # COESA FORK: nenhuma chamada enterprise sai para o Hub. Falha rápido em localhost se algo escapar.
  # Sem licença paga do Hub: nunca há status de assinatura (nem aviso de pagamento atrasado).
  def subscription_status
    nil
  end

  def base_url
    'http://127.0.0.1:9'
  end
end
