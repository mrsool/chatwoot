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

  def requeue_notes(conversation)
    conversation.messages.activity.where('content LIKE ?', '%Requeued%')
  end

  it 'handles an agent with no chats without creating any note' do
    other_chat = create(:conversation, account: account, inbox: inbox, assignee: other, status: :open)

    expect { described_class.perform_now(account.id, agent.id) }.not_to raise_error
    expect(Message.where(account_id: account.id).where('content LIKE ?', '%Requeued%')).to be_empty
    expect(other_chat.reload.assignee_id).to eq(other.id)
  end

  it 'leaves a chat untouched when it is resolved or reassigned after the batch was loaded' do
    first = chat(:open)
    resolved_later = chat(:open)
    reassigned_later = chat(:open)
    raced = false
    allow(Conversations::AssignmentService).to receive(:new).and_wrap_original do |original, **kwargs|
      unless raced
        raced = true
        resolved_later.update_columns(status: Conversation.statuses[:resolved]) # rubocop:disable Rails/SkipsModelValidations
        reassigned_later.update_columns(assignee_id: other.id) # rubocop:disable Rails/SkipsModelValidations
      end
      original.call(**kwargs)
    end

    described_class.perform_now(account.id, agent.id)

    expect(first.reload.assignee_id).to be_nil
    expect(resolved_later.reload.assignee_id).to eq(agent.id)
    expect(requeue_notes(resolved_later)).to be_empty
    expect(reassigned_later.reload.assignee_id).to eq(other.id)
    expect(requeue_notes(reassigned_later)).to be_empty
  end

  it 'unassigns each chat once with one note when two jobs run for the same user' do
    chats = [chat(:open), chat(:open)]
    second_job_ran = false
    allow_any_instance_of(Conversation).to receive(:fazaa_post_requeue_note).and_wrap_original do |original, *args| # rubocop:disable RSpec/AnyInstance
      result = original.call(*args)
      unless second_job_ran
        second_job_ran = true
        described_class.perform_now(account.id, agent.id)
      end
      result
    end

    described_class.perform_now(account.id, agent.id)

    chats.each do |c|
      expect(c.reload.assignee_id).to be_nil
      expect(requeue_notes(c).count).to eq(1)
    end
  end

  it 'isolates a failing chat, reports it and continues with the rest' do
    failing = chat(:open)
    healthy = chat(:open)
    allow(Conversations::AssignmentService).to receive(:new).and_wrap_original do |original, **kwargs|
      raise StandardError, 'boom' if kwargs[:conversation].id == failing.id

      original.call(**kwargs)
    end
    tracker = instance_double(ChatwootExceptionTracker, capture_exception: true)
    allow(ChatwootExceptionTracker).to receive(:new).and_return(tracker)

    expect { described_class.perform_now(account.id, agent.id) }.not_to raise_error

    expect(ChatwootExceptionTracker).to have_received(:new).with(an_instance_of(StandardError), account: account)
    expect(healthy.reload.assignee_id).to be_nil
    expect(requeue_notes(healthy).count).to eq(1)
    expect(failing.reload.assignee_id).to eq(agent.id)
    expect(requeue_notes(failing)).to be_empty
  end

  it 'logs one line with the chat count and latency since the availability change' do
    chat(:open)
    chat(:pending)
    AgentAvailabilityEvent.where(account_id: account.id, user_id: agent.id).update_all(changed_at: 2.seconds.ago) # rubocop:disable Rails/SkipsModelValidations
    lines = []
    allow(Rails.logger).to receive(:info).and_wrap_original do |original, *args, &block|
      lines << args.first if args.first.to_s.start_with?('[fazaa.requeue]')
      original.call(*args, &block)
    end

    described_class.perform_now(account.id, agent.id)

    expect(lines.size).to eq(1)
    expect(lines.first).to match(/\A\[fazaa\.requeue\] account=#{account.id} user=#{agent.id} chats=2 latency_ms=\d+\z/)
    expect(lines.first[/latency_ms=(\d+)/, 1].to_i).to be >= 2000
  end
end
