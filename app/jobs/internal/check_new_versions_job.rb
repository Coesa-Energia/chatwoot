class Internal::CheckNewVersionsJob < ApplicationJob
  queue_as :scheduled_jobs

  # COESA FORK: job de atualização desligado. Tratado depois com outro propósito.
  # Retorno fixo local, sem chamar ChatwootHub. Aceita as opções do upstream
  # (refresh_billing, usado em Super Admin > Settings) só para manter a assinatura.
  def perform(**)
    { 'version' => Chatwoot.config[:version] }
  end

  private

  def update_version_info
    nil
  end
end

Internal::CheckNewVersionsJob.prepend_mod_with('Internal::CheckNewVersionsJob')
