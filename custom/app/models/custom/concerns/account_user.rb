module Custom::Concerns::AccountUser
  extend ActiveSupport::Concern

  included do
    belongs_to :away_reason, optional: true

    before_validation :clear_away_reason, if: :will_save_change_to_availability?
    validate :away_reason_allowed, if: -> { will_save_change_to_availability? && away? }
    after_update_commit :record_availability_change, if: :saved_change_to_availability?
  end

  private

  def clear_away_reason
    self.away_reason_id = nil unless away?
  end

  def away_reason_allowed
    return if account.feature_enabled?('fazaa_wfm') && account.away_reasons.active.exists?(id: away_reason_id)

    errors.add(:base, I18n.t('errors.account_user.away_reason_required'))
  end

  def record_availability_change
    previous = saved_change_to_availability.first
    AgentAvailabilityEvent.create!(account_id: account_id, user_id: user_id, status: availability,
                                   away_reason_id: away_reason_id, changed_at: Time.current)
    Fazaa::AvailabilityChanged.call(account_user: self, previous: previous)
  end
end
