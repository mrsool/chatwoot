# Live SLA wallboard. Reads the enterprise SLA tables only; due times come from
# AppliedSla#frt_due_at/#nrt_due_at/#rt_due_at, which handle business hours.
#
# Rows are capped at MAX_ROWS after sorting; summary counts cover every matching row.
class Fazaa::LiveSlaBoard
  MAX_ROWS = 500
  STATE_RANK = { 'breached' => 0, 'at_risk' => 1, 'on_track' => 2, 'na' => 3 }.freeze
  LIVE_CONVERSATION_STATUSES = %w[open pending snoozed].freeze
  LIVE_SLA_STATUSES = %w[active active_with_misses].freeze
  NA = { state: 'na' }.freeze

  def initialize(account:, filters: {}, now: Time.current)
    @account = account
    @filters = filters.to_h.symbolize_keys
    @now = now
    @at_risk_percent = account.sla_at_risk_threshold_percent
    @window_hours = account.sla_live_hit_rate_window_hours
    @working_hours_cache = {}
  end

  def call
    rows = sorted_rows

    {
      summary: {
        breached: rows.count { |row| row[:worst_state] == 'breached' },
        at_risk: rows.count { |row| row[:worst_state] == 'at_risk' },
        hit_rate: hit_rate,
        window_hours: @window_hours,
        at_risk_percent: @at_risk_percent
      },
      rows: rows.first(MAX_ROWS).map { |row| row.except(:sort_due_at) },
      server_time: @now.to_i
    }
  end

  private

  def sorted_rows
    live_applied_slas.map { |applied_sla| build_row(applied_sla) }
                     .sort_by { |row| [STATE_RANK.fetch(row[:worst_state]), row[:sort_due_at] || Float::INFINITY] }
  end

  def live_applied_slas
    scope = @account.applied_slas
                    .where(sla_status: LIVE_SLA_STATUSES)
                    .with_sla_applicable_conversation
                    .joins(:conversation)
                    .where(conversations: { status: LIVE_CONVERSATION_STATUSES })
                    .includes(:sla_policy, :sla_events, conversation: [:assignee, { inbox: :working_hours }])
    apply_filters(scope)
  end

  def apply_filters(scope)
    conversation_filters = @filters.slice(:inbox_id, :team_id, :assignee_id).compact_blank
    scope = scope.where(conversations: conversation_filters) if conversation_filters.any?
    scope = scope.where(sla_policy_id: @filters[:sla_policy_id]) if @filters[:sla_policy_id].present?
    apply_label_and_attribute_filters(scope)
  end

  def apply_label_and_attribute_filters(scope)
    scope = scope.where(conversation_id: @account.conversations.tagged_with(@filters[:label]).select(:id)) if @filters[:label].present?
    %i[cr_code country].each do |key|
      scope = scope.where("conversations.custom_attributes ->> '#{key}' = ?", @filters[key]) if @filters[key].present?
    end
    scope
  end

  def build_row(applied_sla)
    conversation = applied_sla.conversation
    timers = timers_for(applied_sla, conversation)

    conversation_payload(conversation).merge(
      sla_policy: id_and_name(applied_sla.sla_policy),
      timers: timers,
      worst_state: timers.values.map { |timer| timer[:state] }.min_by { |state| STATE_RANK.fetch(state) },
      sort_due_at: timers.values.filter_map { |timer| timer[:due_at] }.min
    )
  end

  def conversation_payload(conversation)
    {
      conversation_id: conversation.id,
      display_id: conversation.display_id,
      inbox: id_and_name(conversation.inbox),
      assignee: conversation.assignee && id_and_name(conversation.assignee),
      labels: conversation.cached_label_list_array,
      custom_attributes: conversation.custom_attributes
    }
  end

  def id_and_name(record)
    { id: record.id, name: record.name }
  end

  def timers_for(applied_sla, conversation)
    policy = applied_sla.sla_policy
    cache = working_hours_cache_for(policy, conversation.inbox)
    events = applied_sla.sla_events

    {
      frt: timer(policy.first_response_time_threshold, conversation.first_reply_created_at.blank?,
                 events.any?(&:frt?)) { applied_sla.frt_due_at(working_hours_by_day_cache: cache) },
      nrt: timer(policy.next_response_time_threshold, conversation.waiting_since.present?,
                 current_nrt_miss?(events, conversation)) { applied_sla.nrt_due_at(working_hours_by_day_cache: cache) },
      rt: timer(policy.resolution_time_threshold, !conversation.resolved?,
                events.any?(&:rt?)) { applied_sla.rt_due_at(working_hours_by_day_cache: cache) }
    }
  end

  # NRT misses are logged per waiting period, so only an event from the current one counts.
  def current_nrt_miss?(events, conversation)
    conversation.waiting_since.present? && events.any? { |event| event.nrt? && event.created_at >= conversation.waiting_since }
  end

  def timer(threshold, applies, missed)
    return NA if threshold.blank? || !applies

    due_at = yield
    return NA if due_at.nil?

    { state: timer_state(due_at, threshold, missed), due_at: due_at, threshold_seconds: threshold.to_i }
  end

  def timer_state(due_at, threshold, missed)
    remaining = due_at - @now.to_i
    return 'breached' if missed || remaining <= 0
    return 'at_risk' if remaining < threshold * @at_risk_percent / 100.0

    'on_track'
  end

  def working_hours_cache_for(policy, inbox)
    return unless policy.only_during_business_hours?

    @working_hours_cache[inbox.id] ||= inbox.working_hours.index_by(&:day_of_week)
  end

  def hit_rate
    counts = @account.applied_slas.where(updated_at: (@now - @window_hours.hours)..).group(:sla_status).count
    hit = counts.fetch('hit', 0)
    denominator = hit + counts.fetch('missed', 0) + counts.fetch('active_with_misses', 0)
    return if denominator.zero?

    (hit.to_f / denominator).round(4)
  end
end
