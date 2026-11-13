# == Schema Information
#
# Table name: compensation_cap_settings
#
#  id                           :bigint           not null, primary key
#  at_risk_value_limit          :decimal(10, 2)
#  at_risk_window_count_limit   :integer
#  bad_grade_value_limit        :decimal(10, 2)
#  bad_grade_window_count_limit :integer
#  per_order_count_limit        :integer
#  valuable_value_limit         :decimal(10, 2)
#  valuable_window_count_limit  :integer
#  vip_window_count_limit       :integer
#  window_days                  :integer
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  account_id                   :bigint           not null
#  updated_by_id                :bigint
#
# Indexes
#
#  index_compensation_cap_settings_on_account_id  (account_id) UNIQUE
#
# One row per account. Every cap is nullable: nil means MBO uses its own Fallout value.
class CompensationCapSetting < ApplicationRecord
  VALUE_LIMITS = %i[bad_grade_value_limit at_risk_value_limit valuable_value_limit].freeze
  COUNT_LIMITS = {
    per_order_count_limit: 0..100,
    bad_grade_window_count_limit: 0..1000,
    at_risk_window_count_limit: 0..1000,
    valuable_window_count_limit: 0..1000,
    vip_window_count_limit: 0..1000,
    window_days: 1..365
  }.freeze
  CAP_FIELDS = (VALUE_LIMITS + COUNT_LIMITS.keys).freeze

  belongs_to :account
  belongs_to :updated_by, class_name: 'User', optional: true

  validates :account_id, uniqueness: true
  VALUE_LIMITS.each do |field|
    validates field, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100_000 }, allow_nil: true
  end
  COUNT_LIMITS.each do |field, range|
    validates field, numericality: { only_integer: true, greater_than_or_equal_to: range.min, less_than_or_equal_to: range.max }, allow_nil: true
  end

  audited associated_with: :account, except: %i[created_at updated_at updated_by_id] if ChatwootApp.enterprise?

  def self.for(account)
    find_or_initialize_by(account: account)
  end
end
