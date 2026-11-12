require 'rails_helper'

RSpec.describe Fazaa::LiveSlaBoard do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:now) { Time.zone.parse('2026-11-12 10:00:00') }
  let(:frt_policy) do
    create(:sla_policy, account: account, first_response_time_threshold: 300,
                        next_response_time_threshold: nil, resolution_time_threshold: nil)
  end

  around { |example| travel_to(now) { example.run } }

  def create_sla_conversation(age:, policy: frt_policy, status: 'open', sla_status: 'active', **attrs)
    conversation = create(:conversation, account: account, inbox: attrs.delete(:inbox) || inbox, status: status, **attrs)
    conversation.update!(created_at: now - age, waiting_since: nil, first_reply_created_at: nil)
    create(:applied_sla, conversation: conversation, sla_policy: policy, account: account, sla_status: sla_status)
    conversation
  end

  def board(filters = {})
    described_class.new(account: account, filters: filters, now: now).call
  end

  def row_for(result, conversation)
    result[:rows].find { |row| row[:conversation_id] == conversation.id }
  end

  describe 'FRT timer state' do
    it 'is at_risk when the time left is under the at-risk share of the threshold' do
      conversation = create_sla_conversation(age: 250)
      row = row_for(board, conversation)

      expect(row[:timers][:frt]).to eq(state: 'at_risk', due_at: (now - 250 + 300).to_i, threshold_seconds: 300)
      expect(row[:worst_state]).to eq('at_risk')
    end

    it 'is on_track with plenty of time left' do
      conversation = create_sla_conversation(age: 200)
      expect(row_for(board, conversation)[:timers][:frt][:state]).to eq('on_track')
    end

    it 'is breached once the due time has passed' do
      conversation = create_sla_conversation(age: 301)
      expect(row_for(board, conversation)[:timers][:frt][:state]).to eq('breached')
    end

    it 'is na after the first reply' do
      conversation = create_sla_conversation(age: 250)
      conversation.update!(first_reply_created_at: now - 100)

      row = row_for(board, conversation)
      expect(row[:timers][:frt]).to eq(state: 'na')
      expect(row[:worst_state]).to eq('na')
    end

    it 'is breached when an frt SlaEvent exists even though due_at is in the future' do
      conversation = create_sla_conversation(age: 10)
      create(:sla_event, applied_sla: conversation.applied_sla, conversation: conversation, event_type: 'frt')

      expect(row_for(board, conversation)[:timers][:frt][:state]).to eq('breached')
    end

    it 'takes due_at from AppliedSla for business-hours policies' do
      inbox.update!(working_hours_enabled: true)
      frt_policy.update!(only_during_business_hours: true)
      conversation = create_sla_conversation(age: 250)

      expect(row_for(board, conversation)[:timers][:frt][:due_at]).to eq(conversation.applied_sla.frt_due_at)
    end

    it 'uses the account at-risk percent' do
      account.update!(sla_at_risk_threshold_percent: 10)
      conversation = create_sla_conversation(age: 250)

      expect(row_for(board, conversation)[:timers][:frt][:state]).to eq('on_track')
    end
  end

  describe 'NRT and RT timers' do
    let(:policy) do
      create(:sla_policy, account: account, first_response_time_threshold: nil,
                          next_response_time_threshold: 600, resolution_time_threshold: 3600)
    end

    it 'reports nrt as na while not waiting and the nil frt threshold as na' do
      conversation = create_sla_conversation(age: 100, policy: policy)
      timers = row_for(board, conversation)[:timers]

      expect(timers[:frt]).to eq(state: 'na')
      expect(timers[:nrt]).to eq(state: 'na')
      expect(timers[:rt]).to eq(state: 'on_track', due_at: (now - 100 + 3600).to_i, threshold_seconds: 3600)
    end

    it 'runs nrt from waiting_since' do
      conversation = create_sla_conversation(age: 1000, policy: policy)
      conversation.update!(first_reply_created_at: now - 900, waiting_since: now - 580)

      expect(row_for(board, conversation)[:timers][:nrt]).to eq(state: 'at_risk', due_at: (now + 20).to_i, threshold_seconds: 600)
    end

    it 'reports nrt as na before the first reply even while waiting' do
      conversation = create_sla_conversation(age: 1000, policy: policy)
      conversation.update!(waiting_since: now - 590)

      expect(row_for(board, conversation)[:timers][:nrt]).to eq(state: 'na')
    end

    it 'ignores an nrt SlaEvent from an earlier waiting period' do
      conversation = create_sla_conversation(age: 1000, policy: policy)
      create(:sla_event, applied_sla: conversation.applied_sla, conversation: conversation, event_type: 'nrt', created_at: now - 300)
      conversation.update!(first_reply_created_at: now - 900, waiting_since: now - 10)

      expect(row_for(board, conversation)[:timers][:nrt][:state]).to eq('on_track')
    end

    it 'counts an nrt SlaEvent from the current waiting period as breached' do
      conversation = create_sla_conversation(age: 1000, policy: policy)
      conversation.update!(first_reply_created_at: now - 900, waiting_since: now - 10)
      create(:sla_event, applied_sla: conversation.applied_sla, conversation: conversation, event_type: 'nrt', created_at: now - 5)

      expect(row_for(board, conversation)[:timers][:nrt][:state]).to eq('breached')
    end
  end

  describe 'row selection' do
    it 'includes open, pending and snoozed conversations with active or active_with_misses SLAs only' do
      open_conv = create_sla_conversation(age: 10)
      pending_conv = create_sla_conversation(age: 10, status: 'pending')
      snoozed_conv = create_sla_conversation(age: 10, status: 'snoozed')
      missed_conv = create_sla_conversation(age: 400, sla_status: 'active_with_misses')
      resolved_conv = create_sla_conversation(age: 10, status: 'resolved')
      hit_conv = create_sla_conversation(age: 10, sla_status: 'hit')

      ids = board[:rows].pluck(:conversation_id)
      expect(ids).to contain_exactly(open_conv.id, pending_conv.id, snoozed_conv.id, missed_conv.id)
      expect(ids).not_to include(resolved_conv.id, hit_conv.id)
    end

    it 'excludes other accounts' do
      other = create(:conversation)
      create(:applied_sla, conversation: other, sla_policy: create(:sla_policy, account: other.account), account: other.account)

      expect(board[:rows]).to be_empty
    end
  end

  describe 'filters' do
    it 'narrows by inbox_id' do
      other_inbox = create(:inbox, account: account)
      keep = create_sla_conversation(age: 10)
      create_sla_conversation(age: 10, inbox: other_inbox)

      expect(board(inbox_id: inbox.id)[:rows].pluck(:conversation_id)).to eq([keep.id])
    end

    it 'narrows by cr_code and country' do
      keep = create_sla_conversation(age: 10, custom_attributes: { 'cr_code' => 'CR124', 'country' => 'SA' })
      create_sla_conversation(age: 10, custom_attributes: { 'cr_code' => 'CR999', 'country' => 'SA' })

      expect(board(cr_code: 'CR124')[:rows].pluck(:conversation_id)).to eq([keep.id])
      expect(board(country: 'SA')[:rows].size).to eq(2)
    end

    it 'narrows by exact label' do
      keep = create_sla_conversation(age: 10)
      keep.update!(label_list: ['vip'])
      other = create_sla_conversation(age: 10)
      other.update!(label_list: ['vip2'])

      expect(board(label: 'vip')[:rows].pluck(:conversation_id)).to eq([keep.id])
    end

    it 'narrows by assignee_id, team_id and sla_policy_id' do
      agent = create(:user, account: account, role: :agent)
      team = create(:team, account: account)
      create(:inbox_member, user: agent, inbox: inbox)
      create(:team_member, team: team, user: agent)
      keep = create_sla_conversation(age: 10, assignee: agent, team: team)
      create_sla_conversation(age: 10)

      expect(board(assignee_id: agent.id)[:rows].pluck(:conversation_id)).to eq([keep.id])
      expect(board(team_id: team.id)[:rows].pluck(:conversation_id)).to eq([keep.id])
      expect(board(sla_policy_id: frt_policy.id + 1000)[:rows]).to be_empty
    end
  end

  describe 'row payload and ordering' do
    it 'serialises the row' do
      agent = create(:user, account: account, role: :agent, name: 'Agent A')
      create(:inbox_member, user: agent, inbox: inbox)
      attributes = { 'cr_code' => 'CR124', 'country' => 'SA', 'phone' => '+966500000000' }
      conversation = create_sla_conversation(age: 10, assignee: agent, custom_attributes: attributes)
      conversation.update!(label_list: ['vip'])

      row = row_for(board, conversation)
      expect(row).to include(
        conversation_id: conversation.id,
        display_id: conversation.display_id,
        inbox: { id: inbox.id, name: inbox.name },
        assignee: { id: agent.id, name: 'Agent A' },
        sla_policy: { id: frt_policy.id, name: frt_policy.name },
        labels: ['vip'],
        custom_attributes: { 'cr_code' => 'CR124', 'country' => 'SA' }
      )
    end

    it 'returns a nil assignee when unassigned' do
      conversation = create_sla_conversation(age: 10)
      expect(row_for(board, conversation)[:assignee]).to be_nil
    end

    it 'sorts breached, at_risk, on_track, na, then by earliest due_at' do
      on_track = create_sla_conversation(age: 10)
      replied = create_sla_conversation(age: 10)
      replied.update!(first_reply_created_at: now)
      breached_late = create_sla_conversation(age: 310)
      breached_early = create_sla_conversation(age: 400)
      at_risk = create_sla_conversation(age: 250)
      on_track_earlier = create_sla_conversation(age: 100)

      expect(board[:rows].pluck(:conversation_id))
        .to eq([breached_early.id, breached_late.id, at_risk.id, on_track_earlier.id, on_track.id, replied.id])
    end

    it 'caps rows but counts the summary over every matching row' do
      stub_const("#{described_class}::MAX_ROWS", 2)
      3.times { create_sla_conversation(age: 400) }
      create_sla_conversation(age: 250)

      result = board
      expect(result[:rows].size).to eq(2)
      expect(result[:summary]).to include(breached: 3, at_risk: 1)
    end

    it 'does not run per-row queries' do
      create_sla_conversation(age: 10, assignee: create(:user, account: account))
      warm = count_queries { board }
      3.times do
        conv = create_sla_conversation(age: 10, assignee: create(:user, account: account), inbox: create(:inbox, account: account))
        conv.update!(label_list: ['vip'])
        create(:sla_event, applied_sla: conv.applied_sla, conversation: conv, event_type: 'frt')
      end

      expect(count_queries { board }).to eq(warm)
    end
  end

  describe 'summary' do
    it 'reports hit_rate over the window, settings and server_time' do
      policy = create(:sla_policy, account: account)
      3.times { create_sla_conversation(age: 10, policy: policy, status: 'resolved', sla_status: 'hit') }
      create_sla_conversation(age: 10, policy: policy, status: 'resolved', sla_status: 'missed')
      create_sla_conversation(age: 10, policy: policy, status: 'resolved', sla_status: 'hit')
        .applied_sla.update!(updated_at: now - 25.hours)

      result = board
      expect(result[:summary]).to eq(breached: 0, at_risk: 0, hit_rate: 0.75, window_hours: 24, at_risk_percent: 20)
      expect(result[:server_time]).to eq(now.to_i)
    end

    it 'counts active_with_misses in the hit_rate denominator' do
      create_sla_conversation(age: 10, sla_status: 'hit', status: 'resolved')
      create_sla_conversation(age: 10, sla_status: 'active_with_misses')

      expect(board[:summary][:hit_rate]).to eq(0.5)
    end

    it 'returns a nil hit_rate without data' do
      expect(board[:summary][:hit_rate]).to be_nil
    end
  end

  def count_queries(&)
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
      queries << payload[:sql] unless payload[:cached] || payload[:name] == 'SCHEMA'
    end
    yield
    queries.size
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end
end
