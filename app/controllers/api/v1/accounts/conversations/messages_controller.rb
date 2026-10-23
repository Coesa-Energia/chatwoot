class Api::V1::Accounts::Conversations::MessagesController < Api::V1::Accounts::Conversations::BaseController
  SEARCH_MIN_LENGTH = 2
  SEARCH_LIMIT = 100

  before_action :ensure_api_inbox, only: :update
  before_action :ensure_message_deletable, only: :destroy

  def index
    @messages = message_finder.perform
  end

  # Search inside this conversation (like the WhatsApp "search in chat"): newest match first.
  # The client jumps to each result by loading the history around its id.
  def search
    query = params[:q].to_s.strip
    return render json: { payload: [] } if query.length < SEARCH_MIN_LENGTH

    messages = @conversation.messages.where.not(message_type: :activity)
                            .where('messages.content ILIKE ?', "%#{ActiveRecord::Base.sanitize_sql_like(query)}%")
                            .reorder(created_at: :desc, id: :desc).limit(SEARCH_LIMIT)
    render json: { payload: messages.map { |message| search_result(message) } }
  end

  def create
    user = Current.user || @resource
    mb = Messages::MessageBuilder.new(user, @conversation, params)
    @message = mb.perform
  rescue StandardError => e
    render_could_not_create_error(e.message)
  end

  def update
    Messages::StatusUpdateService.new(message, permitted_params[:status], permitted_params[:external_error]).perform
    @message = message
  end

  # React to a WhatsApp message with an emoji (an empty emoji removes the reaction).
  def react
    error = Whatsapp::SendReactionService.new(message: message, emoji: params[:emoji].to_s.strip).perform
    return render_could_not_create_error(error) if error.present?

    render json: { id: message.id, reactions: message.reload.content_attributes['reactions'] || {} }
  end

  def destroy
    ActiveRecord::Base.transaction do
      # keeps the forward marker so replies to a deleted forward stay out of this conversation
      message.update!(content: I18n.t('conversations.messages.deleted'), content_type: :text,
                      content_attributes: message.content_attributes.slice('forwarded_message_id').merge(deleted: true))
      message.attachments.destroy_all
    end
  end

  def retry
    return if message.blank?

    ::SendReplyJob.perform_later(message.id) if claim_message_retry
  rescue StandardError => e
    render_could_not_create_error(e.message)
  end

  def translate
    return head :ok if already_translated_content_available?

    translated_content = translate_message

    if translated_content.present?
      translations = {}
      translations[permitted_params[:target_language]] = translated_content
      translations = message.translations.merge!(translations) if message.translations.present?
      message.update!(translations: translations, translation_provider: translation_provider)
    end

    render json: { content: translated_content }
  rescue Google::Cloud::Error => e
    # `details` carries the clean human message; `message` includes gRPC debug noise
    render_could_not_create_error(e.details.presence || e.message)
  end

  private

  def translation_provider
    'google_translate'
  end

  def translate_message
    hook = Current.account.hooks.find_by(app_id: 'google_translate')
    Integrations::GoogleTranslate::ProcessorService.new(hook: hook).translate_message(message, permitted_params[:target_language]) if hook
  end

  def message
    @message ||= @conversation.messages.find(permitted_params[:id])
  end

  def message_finder
    @message_finder ||= MessageFinder.new(@conversation, params)
  end

  def search_result(message)
    {
      id: message.id,
      content: message.content,
      message_type: message.message_type,
      private: message.private,
      created_at: message.created_at.to_i,
      sender_name: message.sender&.try(:name)
    }
  end

  def claim_message_retry
    message.with_lock do
      next false unless message.failed?

      Messages::StatusUpdateService.new(message, 'sent').perform
      clear_source_id unless @conversation.inbox.api? || @conversation.inbox.web_widget?
      true
    end
  end

  def clear_source_id
    Rails.logger.info "Cleared older source ID #{message.source_id} for message #{message.id}" if message.source_id.present?
    message.update!(source_id: nil)
  end

  def permitted_params
    params.permit(:id, :target_language, :status, :external_error)
  end

  def already_translated_content_available?
    message.translations.present? && message.translations[permitted_params[:target_language]].present?
  end

  # Agents may only delete messages they sent themselves; admins (and bots) are unrestricted.
  def ensure_message_deletable
    return unless Current.account_user&.agent?
    return if message.outgoing? && message.sender == Current.user

    raise Pundit::NotAuthorizedError
  end

  # API inbox check
  def ensure_api_inbox
    # Only API inboxes can update messages
    render json: { error: 'Message status update is only allowed for API inboxes' }, status: :forbidden unless @conversation.inbox.api?
  end
end

Api::V1::Accounts::Conversations::MessagesController.prepend_mod_with('Api::V1::Accounts::Conversations::MessagesController')
