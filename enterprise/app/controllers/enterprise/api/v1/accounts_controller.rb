class Enterprise::Api::V1::AccountsController < Api::BaseController
  include MfaEnforcementGuard

  before_action :fetch_account
  before_action :validate_token_api_access, if: :authenticate_by_access_token?
  before_action :check_account_mfa_enforcement, if: :authenticate_by_access_token?
  before_action :check_authorization
  before_action :check_cloud_env, only: [:toggle_deletion]

  def limits
    limits = default_limits

    # include id in response to ensure that the store can be updated on the frontend
    render json: { id: @account.id, limits: limits }, status: :ok
  end

  def toggle_deletion
    action_type = params[:action_type]

    case action_type
    when 'delete'
      mark_for_deletion
    when 'undelete'
      unmark_for_deletion
    else
      render json: { error: 'Invalid action_type. Must be either "delete" or "undelete"' }, status: :unprocessable_entity
    end
  end

  private

  def validate_token_api_access
    return if @account.api_and_webhooks_enabled?

    render json: { error: 'API access is not enabled for this account' }, status: :forbidden
  end

  def check_cloud_env
    render json: { error: 'Not found' }, status: :not_found unless ChatwootApp.chatwoot_cloud?
  end

  def default_limits
    {
      'conversation' => {},
      'non_web_inboxes' => {},
      'agents' => {
        'allowed' => @account.usage_limits[:agents],
        'consumed' => @account.account_users.count
      },
      'captain' => @account.usage_limits[:captain]
    }
  end

  def fetch_account
    @account = current_user.accounts.find(params[:id])
    @current_account_user = @account.account_users.find_by(user_id: current_user.id)
  end

  def mark_for_deletion
    reason = 'manual_deletion'

    if @account.mark_for_deletion(reason)
      render json: { message: 'Account marked for deletion' }, status: :ok
    else
      render json: { message: @account.errors.full_messages.join(', ') }, status: :unprocessable_entity
    end
  end

  def unmark_for_deletion
    if @account.unmark_for_deletion
      render json: { message: 'Account unmarked for deletion' }, status: :ok
    else
      render json: { message: @account.errors.full_messages.join(', ') }, status: :unprocessable_entity
    end
  end

  def pundit_user
    {
      user: current_user,
      account: @account,
      account_user: @current_account_user
    }
  end
end
