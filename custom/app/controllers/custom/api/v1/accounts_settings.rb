module Custom::Api::V1::AccountsSettings
  private

  def permitted_settings_attributes
    super + %i[idle_away_timeout_minutes idle_away_reason_id sla_at_risk_threshold_percent sla_live_hit_rate_window_hours]
  end
end
