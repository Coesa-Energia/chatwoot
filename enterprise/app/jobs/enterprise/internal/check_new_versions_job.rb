module Enterprise::Internal::CheckNewVersionsJob
  # COESA FORK: atualização via Hub desligada. Não sobrescreve plano, suporte nem status de assinatura.
  def perform(**)
    synced = super
    update_plan_info
    synced
  end

  private

  def update_plan_info
    nil
  end

  def update_subscription_status
    # Missing on older Hub versions; omission is not evidence of recovery.
    return unless @instance_info.key?('subscription_status')

    previous_status = ChatwootHub.subscription_status
    update_installation_config(key: 'INSTALLATION_SUBSCRIPTION_STATUS', value: @instance_info['subscription_status'])
    return if ChatwootApp.chatwoot_cloud? || previous_status == @instance_info['subscription_status']

    # Publish directly instead of one job per account; dashboards drop events without their own account_id.
    Account.ids.each do |account_id|
      ActionCable.server.broadcast("account_#{account_id}", { event: 'account.billing_updated', data: { account_id: account_id } })
    end
  end

  def update_installation_config(key:, value:)
    config = InstallationConfig.find_or_initialize_by(name: key)
    config.value = value
    config.locked = true
    config.save!
  end

  def reconcile_premium_config_and_features
    # COESA FORK: desligado. Nunca reseta branding nem desliga features premium.
    nil
  end
end
