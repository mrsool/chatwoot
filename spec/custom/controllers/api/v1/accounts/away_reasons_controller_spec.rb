require 'rails_helper'

RSpec.describe 'Away Reasons API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:base_url) { "/api/v1/accounts/#{account.id}/away_reasons" }

  before do
    account.enable_features!('fazaa_wfm')
    account.away_reasons.create!(name: 'Lunch', position: 2)
    account.away_reasons.create!(name: 'Prayer Break', position: 1)
    account.away_reasons.create!(name: 'Retired', position: 3, active: false)
  end

  context 'when the feature flag is off' do
    it 'is rejected by the Pundit handler (401 in this app)' do
      account.disable_features!('fazaa_wfm')
      get base_url, headers: agent.create_new_auth_token
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET #index' do
    it 'returns unauthorized when unauthenticated' do
      get base_url
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns only active reasons in position order to an agent' do
      get base_url, headers: agent.create_new_auth_token
      expect(response).to have_http_status(:success)
      payload = response.parsed_body['payload']
      expect(payload.pluck('name')).to eq(['Prayer Break', 'Lunch'])
      expect(payload.first.keys).to match_array(%w[id name active position])
    end

    it 'ignores all=true for agents' do
      get "#{base_url}?all=true", headers: agent.create_new_auth_token
      expect(response.parsed_body['payload'].pluck('name')).not_to include('Retired')
    end

    it 'includes inactive reasons for admins with all=true' do
      get "#{base_url}?all=true", headers: administrator.create_new_auth_token
      expect(response.parsed_body['payload'].pluck('name')).to include('Retired')
    end
  end

  describe 'POST #create' do
    it 'is forbidden for agents' do
      post base_url, params: { away_reason: { name: 'Prayer' } }, headers: agent.create_new_auth_token
      expect(response).to have_http_status(:unauthorized)
    end

    it 'creates a reason for admins' do
      post base_url, params: { away_reason: { name: 'Prayer' } }, headers: administrator.create_new_auth_token
      expect(response).to have_http_status(:success)
      expect(account.away_reasons.find_by(name: 'Prayer')).to be_present
      expect(response.parsed_body['payload']['name']).to eq('Prayer')
    end

    it 'returns 422 with the uniqueness message when a concurrent insert hits the unique index' do
      allow_any_instance_of(ActiveRecord::Validations::UniquenessValidator).to receive(:validate_each) # rubocop:disable RSpec/AnyInstance
      post base_url, params: { away_reason: { name: 'lunch' } }, headers: administrator.create_new_auth_token
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['message']).to eq('Name has already been taken')
    end
  end

  describe 'PATCH #update' do
    it 'updates a reason for admins' do
      reason = account.away_reasons.find_by(name: 'Lunch')
      patch "#{base_url}/#{reason.id}", params: { away_reason: { name: 'Meal', position: 9 } },
                                        headers: administrator.create_new_auth_token
      expect(response).to have_http_status(:success)
      expect(reason.reload).to have_attributes(name: 'Meal', position: 9)
    end

    it 'is forbidden for agents' do
      reason = account.away_reasons.find_by(name: 'Lunch')
      patch "#{base_url}/#{reason.id}", params: { away_reason: { name: 'Meal' } }, headers: agent.create_new_auth_token
      expect(response).to have_http_status(:unauthorized)
      expect(reason.reload.name).to eq('Lunch')
    end

    it 'returns 422 with the uniqueness message when the rename hits the unique index' do
      allow_any_instance_of(ActiveRecord::Validations::UniquenessValidator).to receive(:validate_each) # rubocop:disable RSpec/AnyInstance
      reason = account.away_reasons.find_by(name: 'Lunch')
      patch "#{base_url}/#{reason.id}", params: { away_reason: { name: 'PRAYER BREAK' } },
                                        headers: administrator.create_new_auth_token
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['message']).to eq('Name has already been taken')
      expect(reason.reload.name).to eq('Lunch')
    end
  end

  describe 'DELETE #destroy' do
    it 'soft deactivates for admins' do
      reason = account.away_reasons.find_by(name: 'Lunch')
      delete "#{base_url}/#{reason.id}", headers: administrator.create_new_auth_token
      expect(response).to have_http_status(:success)
      expect(AwayReason.find(reason.id).active).to be(false)
    end

    it 'is forbidden for agents' do
      reason = account.away_reasons.find_by(name: 'Lunch')
      delete "#{base_url}/#{reason.id}", headers: agent.create_new_auth_token
      expect(response).to have_http_status(:unauthorized)
      expect(reason.reload.active).to be(true)
    end
  end
end
