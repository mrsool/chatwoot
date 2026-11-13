require 'rails_helper'

RSpec.describe 'Fazaa account settings', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:reason) { AwayReason.create!(account: account, name: 'Lunch') }

  def patch_settings(params)
    patch "/api/v1/accounts/#{account.id}", params: params, headers: admin.create_new_auth_token, as: :json
  end

  describe 'PATCH /api/v1/accounts/:id' do
    it 'persists the idle settings' do
      patch_settings(idle_away_timeout_minutes: 10, idle_away_reason_id: reason.id)

      expect(response).to have_http_status(:success)
      expect(account.reload.settings).to include('idle_away_timeout_minutes' => 10, 'idle_away_reason_id' => reason.id)
      expect(response.parsed_body['settings']).to include('idle_away_timeout_minutes' => 10)
    end

    it 'persists the live SLA settings' do
      patch_settings(sla_at_risk_threshold_percent: 30, sla_live_hit_rate_window_hours: 48)

      expect(response).to have_http_status(:success)
      expect(account.reload.sla_at_risk_threshold_percent).to eq(30)
      expect(account.sla_live_hit_rate_window_hours).to eq(48)
    end

    [0, 500, 'abc'].each do |value|
      it "rejects idle_away_timeout_minutes #{value.inspect}" do
        patch_settings(idle_away_timeout_minutes: value)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    it 'resets the idle timeout to null, which disables idle auto-away' do
      account.update!(idle_away_timeout_minutes: 10, idle_away_reason_id: reason.id)

      patch_settings(idle_away_timeout_minutes: nil)

      expect(response).to have_http_status(:success)
      account.reload
      expect(account.settings).to include('idle_away_timeout_minutes' => nil)
      expect(account.fazaa_idle_enabled?).to be(false)
    end

    it 'resets the live SLA settings to null, falling back to the defaults' do
      account.update!(sla_at_risk_threshold_percent: 30, sla_live_hit_rate_window_hours: 48)

      patch_settings(sla_at_risk_threshold_percent: nil, sla_live_hit_rate_window_hours: nil)

      expect(response).to have_http_status(:success)
      account.reload
      expect(account.settings).to include('sla_at_risk_threshold_percent' => nil, 'sla_live_hit_rate_window_hours' => nil)
      expect(account.sla_at_risk_threshold_percent).to eq(20)
      expect(account.sla_live_hit_rate_window_hours).to eq(24)
    end

    it 'is denied for a non-admin' do
      agent = create(:user, account: account, role: :agent)

      patch "/api/v1/accounts/#{account.id}", params: { idle_away_timeout_minutes: 10 },
                                              headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(account.reload.settings).not_to have_key('idle_away_timeout_minutes')
    end

    it 'rejects out-of-range SLA settings' do
      patch_settings(sla_at_risk_threshold_percent: 100)
      expect(response).to have_http_status(:unprocessable_entity)

      patch_settings(sla_live_hit_rate_window_hours: 169)
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'Account helpers' do
    it 'defaults the SLA settings to 20 and 24' do
      expect(account.sla_at_risk_threshold_percent).to eq(20)
      expect(account.sla_live_hit_rate_window_hours).to eq(24)
    end

    it 'is idle-enabled only with timeout and an active reason' do
      expect(account.fazaa_idle_enabled?).to be(false)
      account.update!(idle_away_timeout_minutes: 10, idle_away_reason_id: reason.id)
      expect(account.fazaa_idle_enabled?).to be(true)
      reason.update!(active: false)
      expect(account.fazaa_idle_enabled?).to be(false)
    end

    it 'is not idle-enabled when the timeout is missing' do
      account.update!(idle_away_reason_id: reason.id)
      expect(account.fazaa_idle_enabled?).to be(false)
    end
  end
end
