module Enterprise::Internal::CheckNewVersionsJob
  # COESA FORK: atualização via Hub desligada. Não sobrescreve plano nem suporte.
  def perform
    super
    nil
  end

  private

  def update_plan_info
    nil
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
