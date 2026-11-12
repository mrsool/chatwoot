require 'rails_helper'

RSpec.describe Fazaa::RequeueOnAwayJob do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent, name: 'Sara') }
  let(:other) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account, enable_auto_assignment: false) }
  let(:reason) { AwayReason.create!(account: account, name: 'Prayer') }

  before do
    account.enable_features!('fazaa_wfm')
    create(:inbox_member, inbox: inbox, user: agent)
    agent.account_users.find_by(account_id: account.id).update!(availability: :away, away_reason_id: reason.id)
  end

  def chat(status)
    create(:conversation, account: account, inbox: inbox, assignee: agent, status: status)
  end

  it 'unassigns open and pending chats with one reason note each, leaving resolved ones' do
    open_chats = [chat(:open), chat(:open), chat(:pending)]
    resolved = chat(:resolved)

    described_class.perform_now(account.id, agent.id)

    open_chats.each do |c|
      c.reload
      expect(c.assignee_id).to be_nil
      notes = c.messages.activity.where('content LIKE ?', '%Requeued%')
      expect(notes.count).to eq(1)
      expect(notes.first.content).to eq('Requeued — Sara is away: Prayer')
    end
    expect(resolved.reload.assignee_id).to eq(agent.id)
  end

  it 'reassigns to another online member on a legacy inbox, never the away agent' do
    inbox.update!(enable_auto_assignment: true)
    create(:inbox_member, inbox: inbox, user: other)
    conversation = chat(:open)
    allow(OnlineStatusTracker).to receive(:get_available_users)
      .and_return({ agent.id.to_s => 'away', other.id.to_s => 'online' })

    described_class.perform_now(account.id, agent.id)

    expect(conversation.reload.assignee_id).to eq(other.id)
  end

  it 'does nothing when the agent is back online' do
    conversation = chat(:open)
    agent.account_users.find_by(account_id: account.id).update!(availability: :online)

    described_class.perform_now(account.id, agent.id)

    expect(conversation.reload.assignee_id).to eq(agent.id)
    expect(conversation.messages.activity.where('content LIKE ?', '%Requeued%')).to be_empty
  end

  it 'handles an agent with no chats' do
    expect { described_class.perform_now(account.id, agent.id) }.not_to raise_error
  end
end
