class AgentAvailabilityEvent < ApplicationRecord
  belongs_to :account
  belongs_to :user
  belongs_to :away_reason, optional: true

  enum status: { online: 0, offline: 1, busy: 2, away: 3 }
end
