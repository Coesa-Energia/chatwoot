# frozen_string_literal: true

FactoryBot.define do
  factory :inbox_member do
    user { create(:user, :with_avatar) }
    inbox
    # In the app a new member only sees their own conversations (the column default). Specs that are not
    # about that restriction want a member that sees the whole inbox; pass `see_all_conversations: false` to restrict.
    see_all_conversations { true }
  end
end
