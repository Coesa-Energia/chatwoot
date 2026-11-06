# Descadastro de remarketing (Coesa): o cliente clica no botão de resposta rápida
# "Não quero receber mais" de um template. O contato fica marcado, recebe um aviso
# e a conversa é finalizada. Enquanto o contato tiver a etiqueta, nenhum template
# MARKETING sai para ele (ver Whatsapp::SendOnWhatsappService). Para reativar,
# basta tirar a etiqueta do contato.
class Whatsapp::MarketingUnsubscribeService
  BUTTON_TEXT = 'Não quero receber mais'.freeze
  LABEL = 'descadastrado'.freeze
  DATE_ATTRIBUTE = 'descadastro_marketing_em'.freeze
  CONFIRMATION = 'Pronto, você não vai mais receber nossas mensagens. Se quiser falar com a gente, é só chamar aqui.'.freeze

  pattr_initialize [:conversation!]

  # Só o clique no botão de um template chega como type "button"; texto digitado chega como "text".
  def self.unsubscribe_click?(whatsapp_message)
    return false unless whatsapp_message[:type] == 'button'

    [whatsapp_message.dig(:button, :text), whatsapp_message.dig(:button, :payload)].any? { |value| value.to_s.strip == BUTTON_TEXT }
  end

  def self.unsubscribed?(contact)
    contact.label_list.include?(LABEL)
  end

  def self.marketing_template?(channel, template_name)
    Array(channel.message_templates).any? { |template| template['name'] == template_name && template['category'] == 'MARKETING' }
  end

  def perform
    ensure_label_exists
    mark_contact
    # A etiqueta na conversa também impede a pesquisa de satisfação ao finalizar (ver CsatSurveyService).
    conversation.add_labels([LABEL])
    send_confirmation
    conversation.resolved!
  end

  private

  delegate :contact, :account, to: :conversation

  def ensure_label_exists
    account.labels.find_or_create_by!(title: LABEL)
  end

  def mark_contact
    contact.add_labels([LABEL]) unless self.class.unsubscribed?(contact)
    contact.update!(custom_attributes: contact.custom_attributes.merge(DATE_ATTRIBUTE => Time.zone.now.iso8601))
  end

  def send_confirmation
    conversation.messages.create!(
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :outgoing,
      content: CONFIRMATION
    )
  end
end
