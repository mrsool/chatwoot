require 'rails_helper'

RSpec.describe '/api/v1/widget/order_conversations', type: :request do
  let(:account) { create(:account) }
  let(:web_widget) { create(:channel_widget, account: account) }
  let(:identifier) { 'courier-1' }
  let(:identifier_hash) { OpenSSL::HMAC.hexdigest('sha256', web_widget.hmac_token, identifier) }
  let(:params) do
    { website_token: web_widget.website_token, identifier: identifier, identifier_hash: identifier_hash,
      contact_reason: 'Payment issue', order_id: '9001' }
  end

  describe 'POST /api/v1/widget/order_conversations' do
    it 'creates a conversation for the identified contact and returns a token that opens it' do
      post api_v1_widget_order_conversations_url, params: params, as: :json

      expect(response).to have_http_status(:success)
      conversation = web_widget.inbox.conversations.find_by!(display_id: response.parsed_body['conversation_id'])
      expect(conversation.contact.identifier).to eq(identifier)
      expect(conversation.contact_inbox.hmac_verified).to be(true)
      expect(conversation.custom_attributes).to eq('contact_reason' => 'Payment issue', 'order_id' => '9001')

      get api_v1_widget_conversations_url,
          params: { website_token: web_widget.website_token, conversation_id: conversation.display_id },
          headers: { 'X-Auth-Token' => response.parsed_body['auth_token'] },
          as: :json

      expect(response.parsed_body['id']).to eq(conversation.display_id)
    end

    it 'reuses an open conversation for the same order' do
      post api_v1_widget_order_conversations_url, params: params, as: :json
      first_id = response.parsed_body['conversation_id']

      post api_v1_widget_order_conversations_url, params: params, as: :json

      expect(response.parsed_body['conversation_id']).to eq(first_id)
      expect(web_widget.inbox.conversations.count).to eq(1)
    end

    it 'creates a new conversation when the previous one for the order is resolved' do
      post api_v1_widget_order_conversations_url, params: params, as: :json
      first_id = response.parsed_body['conversation_id']
      web_widget.inbox.conversations.find_by!(display_id: first_id).resolved!

      post api_v1_widget_order_conversations_url, params: params, as: :json

      expect(response.parsed_body['conversation_id']).not_to eq(first_id)
    end

    it 'creates a new conversation for a different order' do
      post api_v1_widget_order_conversations_url, params: params, as: :json
      first_id = response.parsed_body['conversation_id']

      post api_v1_widget_order_conversations_url, params: params.merge(order_id: '9002'), as: :json

      expect(response.parsed_body['conversation_id']).not_to eq(first_id)
    end

    it 'returns unauthorized for an invalid identifier hash' do
      post api_v1_widget_order_conversations_url, params: params.merge(identifier_hash: 'invalid'), as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(web_widget.inbox.conversations.count).to eq(0)
    end

    it 'returns unprocessable entity when order_id is missing' do
      post api_v1_widget_order_conversations_url, params: params.except(:order_id), as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
