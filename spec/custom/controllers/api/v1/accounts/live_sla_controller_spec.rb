require 'rails_helper'

RSpec.describe 'Live SLA API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:url) { "/api/v1/accounts/#{account.id}/reports/live_sla" }

  before do
    account.enable_features!('sla', 'fazaa_sla_live')
    policy = create(:sla_policy, account: account)
    conversation = create(:conversation, account: account, custom_attributes: { 'cr_code' => 'CR124', 'email' => 'x@example.com' })
    create(:applied_sla, conversation: conversation, sla_policy: policy, account: account)
  end

  it 'rejects unauthenticated requests' do
    get url
    expect(response).to have_http_status(:unauthorized)
  end

  it 'rejects agents (Pundit handler renders 401)' do
    get url, headers: agent.create_new_auth_token, as: :json
    expect(response).not_to have_http_status(:ok)
    expect(response).to have_http_status(:unauthorized)
  end

  it 'is forbidden when the sla flag is off' do
    account.disable_features!('sla')
    get url, headers: administrator.create_new_auth_token, as: :json
    expect(response).not_to have_http_status(:ok)
    expect(response).to have_http_status(:forbidden)
  end

  it 'is forbidden when the fazaa_sla_live flag is off' do
    account.disable_features!('fazaa_sla_live')
    get url, headers: administrator.create_new_auth_token, as: :json
    expect(response).not_to have_http_status(:ok)
    expect(response).to have_http_status(:forbidden)
  end

  it 'returns the board to administrators and passes filters through' do
    get url, params: { cr_code: 'CR124' }, headers: administrator.create_new_auth_token

    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body.keys).to contain_exactly('summary', 'rows', 'server_time')
    expect(body['summary'].keys).to contain_exactly('breached', 'at_risk', 'hit_rate', 'window_hours', 'at_risk_percent')
    expect(body['rows'].size).to eq(1)
    expect(body['rows'].first['timers'].keys).to contain_exactly('frt', 'nrt', 'rt')
    expect(body['rows'].first['custom_attributes']).to eq('cr_code' => 'CR124')

    get url, params: { cr_code: 'NOPE' }, headers: administrator.create_new_auth_token
    expect(response.parsed_body['rows']).to be_empty
  end
end
