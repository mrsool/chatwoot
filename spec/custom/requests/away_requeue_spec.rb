require 'rails_helper'

RSpec.describe 'Going away requeues the agent chats', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account, enable_auto_assignment: true) }
  let(:reason) { AwayReason.create!(account: account, name: 'Prayer') }

  before do
    account.enable_features!('fazaa_wfm')
    create(:inbox_member, inbox: inbox, user: agent)
  end

  it 'enqueues the requeue job on high and unassigns the open chats once it runs' do
    open_chats = [:open, :pending].map do |status|
      create(:conversation, account: account, inbox: inbox, assignee: agent, status: status)
    end
    resolved = create(:conversation, account: account, inbox: inbox, assignee: agent, status: :resolved)

    expect do
      post '/api/v1/profile/availability',
           params: { profile: { availability: 'away', account_id: account.id, away_reason_id: reason.id } },
           headers: agent.create_new_auth_token, as: :json
    end.to have_enqueued_job(Fazaa::RequeueOnAwayJob).with(account.id, agent.id).on_queue('high')
    expect(response).to have_http_status(:success)

    perform_enqueued_jobs(only: Fazaa::RequeueOnAwayJob)

    open_chats.each do |conversation|
      expect(conversation.reload.assignee_id).to be_nil
      expect(conversation.messages.activity.where('content LIKE ?', '%Requeued%').count).to eq(1)
    end
    expect(resolved.reload.assignee_id).to eq(agent.id)
  end
end
