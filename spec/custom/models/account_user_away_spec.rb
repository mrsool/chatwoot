require 'rails_helper'

RSpec.describe AccountUser do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, role: :agent) }
  let(:account_user) { user.account_users.find_by(account_id: account.id) }
  let!(:reason) { AwayReason.create!(account: account, name: 'Prayer') }

  context 'when fazaa_wfm is enabled' do
    before { account.enable_features!('fazaa_wfm') }

    it 'is invalid without a reason' do
      account_user.availability = :away
      expect(account_user).not_to be_valid
      expect(account_user.errors.full_messages.join).to include('Away reason is required')
    end

    it 'is invalid with a reason from another account' do
      other = AwayReason.create!(account: create(:account), name: 'Prayer')
      account_user.assign_attributes(availability: :away, away_reason_id: other.id)
      expect(account_user).not_to be_valid
    end

    it 'is invalid with an inactive reason' do
      reason.update!(active: false)
      account_user.assign_attributes(availability: :away, away_reason_id: reason.id)
      expect(account_user).not_to be_valid
    end

    it 'saves with a valid reason and writes one event' do
      expect(Fazaa::AvailabilityChanged).to receive(:call).with(account_user: account_user, previous: 'online')
      expect { account_user.update!(availability: :away, away_reason_id: reason.id) }
        .to change(AgentAvailabilityEvent, :count).by(1)
      event = AgentAvailabilityEvent.last
      expect(event).to have_attributes(account_id: account.id, user_id: user.id, status: 'away', away_reason_id: reason.id)
      expect(event.changed_at).to be_present
    end

    it 'drops a stray reason on a non-away agent' do
      account_user.update!(away_reason_id: reason.id)
      expect(account_user.reload.away_reason_id).to be_nil
    end

    context 'when already away' do
      before { account_user.update!(availability: :away, away_reason_id: reason.id) }

      it 'clears the reason and writes an event when going online' do
        expect { account_user.update!(availability: :online) }.to change(AgentAvailabilityEvent, :count).by(1)
        expect(account_user.reload.away_reason_id).to be_nil
        expect(AgentAvailabilityEvent.last.status).to eq('online')
      end

      it 'logs a reason switch as one event without requeueing' do
        break_reason = AwayReason.create!(account: account, name: 'Break')
        clear_enqueued_jobs
        expect { account_user.update!(away_reason_id: break_reason.id) }.to change(AgentAvailabilityEvent, :count).by(1)
        expect(Fazaa::RequeueOnAwayJob).not_to have_been_enqueued
        expect(AgentAvailabilityEvent.last).to have_attributes(status: 'away', away_reason_id: break_reason.id)
      end

      it 'rejects switching to a reason from another account' do
        other = AwayReason.create!(account: create(:account), name: 'Other')
        expect(account_user.update(away_reason_id: other.id)).to be(false)
      end

      it 'rejects clearing the reason while away' do
        expect(account_user.update(away_reason_id: nil)).to be(false)
      end

      it 'stays valid on an unrelated save after the reason is deactivated' do
        reason.update!(active: false)
        expect(account_user.reload.update(auto_offline: false)).to be(true)
        expect(account_user.reload).to be_away
        expect(account_user.away_reason_id).to eq(reason.id)
      end

      it 'is excluded from inbox available_agents' do
        inbox = create(:inbox, account: account)
        create(:inbox_member, inbox: inbox, user: user)
        expect(inbox.available_agents.map(&:user_id)).not_to include(user.id)
      end
    end
  end

  context 'when fazaa_wfm is disabled' do
    it 'rejects away' do
      account_user.assign_attributes(availability: :away, away_reason_id: reason.id)
      expect(account_user).not_to be_valid
      expect(account_user.errors.full_messages.join).to include('not enabled')
    end
  end
end
