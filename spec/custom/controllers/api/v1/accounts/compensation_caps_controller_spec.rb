require 'rails_helper'

RSpec.describe 'Compensation Caps API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:url) { "/api/v1/accounts/#{account.id}/compensation_caps" }
  let(:cap_keys) { CompensationCapSetting::CAP_FIELDS.map(&:to_s) }

  before { account.enable_features!('fazaa_compensation_caps') }

  def patch_caps(attrs, user: administrator)
    patch url, params: { compensation_caps: attrs }, headers: user.create_new_auth_token, as: :json
  end

  describe 'GET' do
    it 'returns all nil caps when nothing is stored' do
      get url, headers: administrator.create_new_auth_token
      expect(response).to have_http_status(:ok)
      payload = response.parsed_body['payload']
      expect(payload.keys).to match_array(cap_keys + %w[updated_at updated_by])
      expect(cap_keys.map { |k| payload[k] }).to all(be_nil)
      expect(payload['updated_by']).to be_nil
    end

    it 'rejects agents' do
      get url, headers: agent.create_new_auth_token
      expect(response).to have_http_status(:unauthorized)
    end

    it 'is rejected when the flag is off' do
      account.disable_features!('fazaa_compensation_caps')
      get url, headers: administrator.create_new_auth_token
      expect(response).to have_http_status(:unauthorized)
    end

    it 'authenticates with an api_access_token header' do
      get url, headers: { 'api_access_token' => administrator.access_token.token }
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'PATCH' do
    it 'stores caps and returns numbers' do
      patch_caps({ at_risk_value_limit: 30, valuable_value_limit: '50.5', vip_window_count_limit: 10, window_days: 30 })
      expect(response).to have_http_status(:ok)
      payload = response.parsed_body['payload']
      expect(payload['valuable_value_limit']).to eq(50.5)
      expect(payload['valuable_value_limit']).to be_a(Float)
      expect(payload['vip_window_count_limit']).to eq(10)
      expect(payload['updated_by']['id']).to eq(administrator.id)

      get url, headers: administrator.create_new_auth_token
      expect(response.parsed_body['payload']).to include(
        'at_risk_value_limit' => 30.0, 'valuable_value_limit' => 50.5, 'vip_window_count_limit' => 10, 'window_days' => 30
      )
    end

    it 'clears a cap to nil with a blank string' do
      patch_caps({ at_risk_value_limit: 30 })
      patch_caps({ at_risk_value_limit: '' })
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['payload']['at_risk_value_limit']).to be_nil
      expect(CompensationCapSetting.for(account).at_risk_value_limit).to be_nil
    end

    it 'clears a cap to nil with a JSON null' do
      patch_caps({ at_risk_value_limit: 30 })
      patch_caps({ at_risk_value_limit: nil })
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['payload']['at_risk_value_limit']).to be_nil
      expect(CompensationCapSetting.for(account).at_risk_value_limit).to be_nil
    end

    it 'is rejected when the flag is off' do
      account.disable_features!('fazaa_compensation_caps')
      patch_caps({ window_days: 7 })
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 422 when a concurrent first save hits the unique index' do
      allow_any_instance_of(CompensationCapSetting).to receive(:save!).and_raise(ActiveRecord::RecordNotUnique) # rubocop:disable RSpec/AnyInstance
      patch_caps({ window_days: 7 })
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['message']).to be_present
    end

    it 'returns 422 for invalid values' do
      patch_caps({ window_days: 0 })
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['attributes']).to include('window_days')
    end

    it 'rejects agents' do
      patch_caps({ window_days: 7 }, user: agent)
      expect(response).to have_http_status(:unauthorized)
    end

    it 'writes an audit log', if: ChatwootApp.enterprise? do
      patch_caps({ at_risk_value_limit: 30 })
      log = Enterprise::AuditLog.where(auditable_type: 'CompensationCapSetting', associated: account).last
      expect(log).to be_present
      expect(log.audited_changes).to include('at_risk_value_limit')
    end
  end
end
