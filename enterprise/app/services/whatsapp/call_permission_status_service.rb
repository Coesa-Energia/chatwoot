# Reads what the contact allowed this number to do (GET /{phone}/call_permissions) and reduces Meta's
# permission + action-limit payload to what the dashboard shows an agent.
class Whatsapp::CallPermissionStatusService
  pattr_initialize [:channel!, :recipient!]

  def perform
    data = channel.provider_service.fetch_call_permissions(recipient)
    permission = data['permission'] || {}
    actions = Array(data['actions']).index_by { |action| action['action_name'] }
    request_action = actions['send_call_permission_request'] || {}

    {
      status: permission['status'] || 'no_permission',
      expires_at: permission['expiration_time']&.to_i,
      can_call: actions.dig('start_call', 'can_perform_action') != false && permission['status'].in?(%w[temporary permanent]),
      can_request: request_action['can_perform_action'] != false,
      request_limit_reset_at: limit_reset_at(request_action)
    }
  rescue Voice::CallErrors::CallFailed => e
    { status: 'unknown', error: e.message }
  end

  private

  # When a limit is exhausted Meta says when it frees up; with several, the last one gates the next request.
  def limit_reset_at(action)
    Array(action['limits']).filter_map { |limit| limit['limit_expiration_time']&.to_i }.max
  end
end
