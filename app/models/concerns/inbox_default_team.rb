# Optional team that every new conversation of the inbox starts with (see Conversation#apply_inbox_default_team).
module InboxDefaultTeam
  extend ActiveSupport::Concern

  included do
    belongs_to :default_team, class_name: 'Team', optional: true
    validate :default_team_belongs_to_account
  end

  private

  def default_team_belongs_to_account
    return if default_team_id.blank? || account.teams.exists?(id: default_team_id)

    errors.add(:default_team_id, :invalid)
  end
end
