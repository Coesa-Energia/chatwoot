# Raised when a WhatsApp send failed in a way that is safe to retry later:
# Meta rate limited the request, or the request never reached Meta.
# SendReplyJob retries these with backoff and marks the message failed when attempts run out.
class CustomExceptions::WhatsappRetryableError < CustomExceptions::Base
  def message
    I18n.t("errors.whatsapp.retryable.#{@data[:reason]}")
  end

  def http_status
    :too_many_requests
  end
end
