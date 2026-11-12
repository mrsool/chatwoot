# Requeues an agent's open chats when they go from online/busy to away/offline.
class Fazaa::AvailabilityChanged
  ACTIVE = %w[online busy].freeze
  INACTIVE = %w[away offline].freeze

  def self.call(account_user:, previous:)
    return unless ACTIVE.include?(previous) && INACTIVE.include?(account_user.availability)
    return unless account_user.account.feature_enabled?('fazaa_wfm')

    Fazaa::RequeueOnAwayJob.set(queue: :high).perform_later(account_user.account_id, account_user.user_id)
  end
end
