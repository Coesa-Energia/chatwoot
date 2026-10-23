require 'rails_helper'

RSpec.describe Conversation, '#team' do
  let(:account) { create(:account) }
  let(:team) { create(:team, account: account) }
  let(:other_team) { create(:team, account: account) }
  let(:inbox) { create(:inbox, account: account, default_team: team, enable_auto_assignment: false) }

  it 'starts new conversations with the default team of the inbox' do
    conversation = create(:conversation, account: account, inbox: inbox)

    expect(conversation.team).to eq(team)
  end

  it 'does not override a team chosen when the conversation is created' do
    conversation = create(:conversation, account: account, inbox: inbox, team: other_team)

    expect(conversation.team).to eq(other_team)
  end

  it 'leaves the team empty when the inbox has no default team' do
    plain_inbox = create(:inbox, account: account, enable_auto_assignment: false)

    expect(create(:conversation, account: account, inbox: plain_inbox).team).to be_nil
  end

  it 'does not add an activity message for the automatic team' do
    conversation = nil
    expect { conversation = create(:conversation, account: account, inbox: inbox) }
      .not_to have_enqueued_job(Conversations::ActivityMessageJob)
    expect(conversation.team).to eq(team)
  end

  it 'only accepts a default team of the same account' do
    foreign_team = create(:team)

    inbox.default_team = foreign_team

    expect(inbox).not_to be_valid
  end

  it 'clears the default team of the inboxes when the team is deleted' do
    inbox
    team.destroy!

    expect(inbox.reload.default_team_id).to be_nil
  end
end
