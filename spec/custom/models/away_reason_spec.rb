require 'rails_helper'

RSpec.describe AwayReason do
  let(:account) { create(:account) }

  it 'requires a name' do
    expect(described_class.new(account: account, name: nil)).not_to be_valid
  end

  it 'rejects a duplicate name in the same account ignoring case' do
    described_class.create!(account: account, name: 'Prayer')
    expect(described_class.new(account: account, name: 'prayer')).not_to be_valid
  end

  it 'allows the same name in another account' do
    described_class.create!(account: account, name: 'Prayer')
    expect(described_class.new(account: create(:account), name: 'Prayer')).to be_valid
  end

  it 'scopes active reasons' do
    active = described_class.create!(account: account, name: 'Lunch')
    described_class.create!(account: account, name: 'Break', active: false)
    expect(described_class.active).to eq([active])
  end

  it 'orders by position then id' do
    second = described_class.create!(account: account, name: 'B', position: 2)
    first = described_class.create!(account: account, name: 'A', position: 1)
    expect(account.away_reasons.to_a).to eq([first, second])
  end
end
