# == Schema Information
#
# Table name: dashboard_apps
#
#  id         :bigint           not null, primary key
#  content    :jsonb
#  inbox_ids  :bigint           default([]), not null, is an Array
#  title      :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#  user_id    :bigint
#
# Indexes
#
#  index_dashboard_apps_on_account_id  (account_id)
#  index_dashboard_apps_on_user_id     (user_id)
#
class DashboardApp < ApplicationRecord
  belongs_to :user
  belongs_to :account
  validate :validate_content
  before_validation :keep_account_inbox_ids

  private

  # inbox_ids come from the request; keep only inboxes of this account. Empty = shown in every inbox.
  def keep_account_inbox_ids
    ids = Array(inbox_ids).compact_blank.map(&:to_i).uniq
    self.inbox_ids = ids.empty? || account.nil? ? [] : account.inboxes.where(id: ids).pluck(:id)
  end

  def validate_content
    has_invalid_data = self[:content].blank? || !self[:content].is_a?(Array)
    self[:content] = [] if has_invalid_data

    content_schema = {
      'type' => 'array',
      'items' => {
        'type' => 'object',
        'required' => %w[url type],
        'properties' => {
          'type' => { 'enum': ['frame'] },
          'url' => { '$ref' => '#/definitions/saneUrl' }
        }
      },
      'definitions' => {
        'saneUrl' => { 'format' => 'uri', 'pattern' => '^https?://' }
      },
      'additionalProperties' => false,
      'minItems' => 1
    }
    errors.add(:content, ': Invalid data') unless JSONSchemer.schema(content_schema.to_json).valid?(self[:content])
  end
end
