require 'rails_helper'

RSpec.describe CompensationCapSetting, type: :model do
  let(:account) { create(:account) }

  def build_with(field, value)
    described_class.new(account: account).tap { |row| row[field] = value }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:account) }
  end

  describe 'ranges' do
    {
      bad_grade_value_limit: 100_000, at_risk_value_limit: 100_000, valuable_value_limit: 100_000,
      per_order_count_limit: 100, bad_grade_window_count_limit: 1000, at_risk_window_count_limit: 1000,
      valuable_window_count_limit: 1000, vip_window_count_limit: 1000
    }.each do |field, max|
      it "validates #{field} within 0..#{max}" do
        expect(build_with(field, 0)).to be_valid
        expect(build_with(field, max)).to be_valid
        expect(build_with(field, -1)).not_to be_valid
        expect(build_with(field, max + 1)).not_to be_valid
        expect(build_with(field, nil)).to be_valid
      end
    end

    it 'validates window_days within 1..365' do
      expect(build_with(:window_days, 1)).to be_valid
      expect(build_with(:window_days, 365)).to be_valid
      expect(build_with(:window_days, 0)).not_to be_valid
      expect(build_with(:window_days, 366)).not_to be_valid
      expect(build_with(:window_days, nil)).to be_valid
    end

    it 'rejects non-integer counts' do
      expect(build_with(:per_order_count_limit, 1.5)).not_to be_valid
      expect(build_with(:window_days, 1.5)).not_to be_valid
    end

    it 'allows decimal value limits' do
      expect(build_with(:at_risk_value_limit, 50.5)).to be_valid
    end
  end

  it 'enforces one row per account' do
    described_class.create!(account: account)
    expect(described_class.new(account: account)).not_to be_valid
  end

  describe '.for' do
    it 'returns the existing row' do
      row = described_class.create!(account: account, window_days: 7)
      expect(described_class.for(account)).to eq(row)
    end

    it 'returns an unsaved row with nil caps when none exists' do
      row = described_class.for(account)
      expect(row).to be_new_record
      expect(described_class::CAP_FIELDS.map { |f| row[f] }).to all(be_nil)
    end
  end
end
