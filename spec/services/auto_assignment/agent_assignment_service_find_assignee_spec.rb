require 'rails_helper'

# Members switched out of an inbox's rotation keep access but are never picked by automatic assignment.
RSpec.describe AutoAssignment::AgentAssignmentService, '#find_assignee' do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account, enable_auto_assignment: false) }
  let(:seller) { create(:user, account: account) }
  let(:support) { create(:user, account: account) }
  let(:conversation) { create(:conversation, inbox: inbox, account: account) }
  let(:allowed_ids) { [seller.id, support.id] }

  before do
    inbox.add_members([seller.id, support.id])
    allow(OnlineStatusTracker).to receive(:get_available_users)
      .and_return(seller.id.to_s => 'online', support.id.to_s => 'online')
  end

  it 'never picks a member that is out of the rotation' do
    inbox.update_rotation([seller.id])

    picks = Array.new(4) { described_class.new(conversation: conversation, allowed_agent_ids: allowed_ids).find_assignee }

    expect(picks.uniq).to eq([seller])
  end

  it 'assigns nobody when the whole inbox is out of the rotation' do
    inbox.update_rotation([])

    expect(described_class.new(conversation: conversation, allowed_agent_ids: allowed_ids).find_assignee).to be_nil
  end

  it 'still rotates between the members that are in it' do
    picks = Array.new(2) { described_class.new(conversation: conversation, allowed_agent_ids: allowed_ids).find_assignee }

    expect(picks.map(&:id)).to match_array(allowed_ids)
  end

  it 'keeps a member that is out of the rotation as an inbox member' do
    inbox.update_rotation([seller.id])

    expect(inbox.reload.member_ids).to include(support.id)
    expect(inbox.rotation_member_ids).to eq([seller.id])
  end
end
