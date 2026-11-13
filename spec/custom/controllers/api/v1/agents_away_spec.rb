require 'rails_helper'

RSpec.describe 'Agents update to away', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }

  before { account.enable_features!('fazaa_wfm') }

  it 'returns 422, not 500, when away has no reason' do
    put "/api/v1/accounts/#{account.id}/agents/#{agent.id}",
        params: { availability: 'away' }, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['message']).to be_present
  end

  it 'accepts away with an active reason' do
    reason = AwayReason.create!(account: account, name: 'Prayer')
    put "/api/v1/accounts/#{account.id}/agents/#{agent.id}",
        params: { availability: 'away', away_reason_id: reason.id }, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['away_reason_id']).to eq(reason.id)
  end
end
