require 'rails_helper'

RSpec.describe Conversation do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:online_agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account, enable_auto_assignment: true) }
  let(:reason) { AwayReason.create!(account: account, name: 'Prayer') }
  let(:agent_account_user) { agent.account_users.find_by(account_id: account.id) }

  before do
    account.enable_features!('fazaa_wfm')
    create(:inbox_member, inbox: inbox, user: agent)
    create(:inbox_member, inbox: inbox, user: online_agent)
    allow(OnlineStatusTracker).to receive(:get_available_users)
      .and_return({ agent.id.to_s => 'away', online_agent.id.to_s => 'online' })
  end

  def assigned_chat(status)
    create(:conversation, account: account, inbox: inbox, assignee: agent, status: status)
  end

  it 'unassigns a snoozed chat reopened while its assignee is away and auto-assigns an online agent' do
    conversation = assigned_chat(:snoozed)
    agent_account_user.update!(availability: :away, away_reason_id: reason.id)

    conversation.open!

    expect(conversation.reload.assignee_id).to eq(online_agent.id)
  end

  it 'leaves a reopened chat unassigned when its assignee is offline and nobody is online' do
    allow(OnlineStatusTracker).to receive(:get_available_users).and_return({})
    conversation = assigned_chat(:resolved)
    agent_account_user.update!(availability: :offline)

    conversation.open!

    expect(conversation.reload.assignee_id).to be_nil
  end

  it 'keeps an online assignee when the chat reopens' do
    conversation = assigned_chat(:snoozed)

    conversation.open!

    expect(conversation.reload.assignee_id).to eq(agent.id)
  end

  it 'keeps an away assignee when fazaa_wfm is off' do
    conversation = assigned_chat(:snoozed)
    agent_account_user.update!(availability: :away, away_reason_id: reason.id)
    account.disable_features!('fazaa_wfm')

    conversation.open!

    expect(conversation.reload.assignee_id).to eq(agent.id)
  end

  it 'does not touch an away assignee on saves that are not a reopen' do
    conversation = assigned_chat(:open)
    agent_account_user.update!(availability: :away, away_reason_id: reason.id)

    conversation.update!(status: :pending)

    expect(conversation.reload.assignee_id).to eq(agent.id)
  end
end
