class Internal::CheckNewVersionsJob < ApplicationJob
  queue_as :scheduled_jobs

  # COESA FORK: job de atualização desligado. Tratado depois com outro propósito.
  # Retorno fixo local, sem chamar ChatwootHub.
  def perform
    return { 'version' => Chatwoot.config[:version] }
  end

  private

  def update_version_info
    return
  end
end

Internal::CheckNewVersionsJob.prepend_mod_with('Internal::CheckNewVersionsJob')
