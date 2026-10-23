# == Schema Information
#
# Table name: conversation_user_states
#
#  id              :bigint           not null, primary key
#  archived_at     :datetime
#  pinned_at       :datetime
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  conversation_id :bigint           not null
#  user_id         :bigint           not null
#
# Indexes
#
#  index_conversation_user_states_on_account_id                   (account_id)
#  index_conversation_user_states_on_conversation_id              (conversation_id)
#  index_conversation_user_states_on_user_id_and_conversation_id  (user_id,conversation_id) UNIQUE
#
class ConversationUserState < ApplicationRecord
  MAX_PINNED = 5

  belongs_to :account
  belongs_to :user
  belongs_to :conversation

  validates :user_id, uniqueness: { scope: :conversation_id }
  validate :pinned_limit, if: -> { pinned_at.present? && pinned_at_changed? }

  before_validation :ensure_account_id

  # Archived conversations stay archived, new messages included, until the agent unarchives them.
  def archived?
    archived_at.present?
  end

  private

  def ensure_account_id
    self.account_id = conversation&.account_id
  end

  def pinned_limit
    others = self.class.where(user_id: user_id, account_id: account_id).where.not(pinned_at: nil).where.not(id: id)
    return if others.count < MAX_PINNED

    errors.add(:base, I18n.t('errors.conversations.pinned_limit', max: MAX_PINNED))
  end
end
