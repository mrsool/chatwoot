require 'rails_helper'

RSpec.describe Fazaa::AvailabilityChanged do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, role: :agent) }
  let(:account_user) { user.account_users.find_by(account_id: account.id) }

  before { account.enable_features!('fazaa_wfm') }

  def change(from, to)
    account_user.availability = to
    described_class.call(account_user: account_user, previous: from)
  end

  it 'enqueues the requeue job on high for online to away' do
    expect { change('online', 'away') }.to have_enqueued_job(Fazaa::RequeueOnAwayJob)
      .with(account.id, user.id).on_queue('high')
  end

  it 'enqueues for busy to offline' do
    expect { change('busy', 'offline') }.to have_enqueued_job(Fazaa::RequeueOnAwayJob)
  end

  it 'does not enqueue again for away to offline' do
    expect { change('away', 'offline') }.not_to have_enqueued_job(Fazaa::RequeueOnAwayJob)
  end

  it 'does not enqueue when the flag is off' do
    account.disable_features!('fazaa_wfm')
    expect { change('online', 'away') }.not_to have_enqueued_job(Fazaa::RequeueOnAwayJob)
  end
end
