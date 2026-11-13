# == Schema Information
#
# Table name: away_reasons
#
#  id         :bigint           not null, primary key
#  active     :boolean          default(TRUE), not null
#  name       :string           not null
#  position   :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#
# Indexes
#
#  index_away_reasons_on_account_id_and_lower_name  (account_id, lower((name)::text)) UNIQUE
#
class AwayReason < ApplicationRecord
  belongs_to :account

  validates :name, presence: true
  validates :name, uniqueness: { scope: :account_id, case_sensitive: false }

  default_scope { order(:position, :id) }
  scope :active, -> { where(active: true) }
end
