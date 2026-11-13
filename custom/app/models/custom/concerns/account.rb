module Custom::Concerns::Account
  extend ActiveSupport::Concern

  DEFAULT_SLA_AT_RISK_THRESHOLD_PERCENT = 20
  DEFAULT_SLA_LIVE_HIT_RATE_WINDOW_HOURS = 24

  included do
    has_many :away_reasons, dependent: :destroy_async

    store_accessor :settings, :idle_away_timeout_minutes, :idle_away_reason_id,
                   :sla_at_risk_threshold_percent, :sla_live_hit_rate_window_hours
  end

  def sla_at_risk_threshold_percent
    (super.presence || DEFAULT_SLA_AT_RISK_THRESHOLD_PERCENT).to_i
  end

  def sla_live_hit_rate_window_hours
    (super.presence || DEFAULT_SLA_LIVE_HIT_RATE_WINDOW_HOURS).to_i
  end

  def fazaa_idle_enabled?
    idle_away_timeout_minutes.present? && idle_away_reason_id.present? &&
      away_reasons.active.exists?(id: idle_away_reason_id)
  end
end
