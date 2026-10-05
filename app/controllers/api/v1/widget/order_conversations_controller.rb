# Lets a native client open (or reuse) a conversation for an order before the widget is loaded.
# The caller proves the contact's identity with the inbox HMAC, and gets back the auth token
# to load the widget (as `cw_conversation`) together with the `conversation_id` to open.
class Api::V1::Widget::OrderConversationsController < ApplicationController
  include WebsiteTokenHelper

  before_action :set_web_widget
  before_action :validate_hmac

  def create
    params.require(%i[contact_reason order_id])

    @contact_inbox = verified_contact_inbox || build_verified_contact_inbox
    @conversation = open_order_conversation || create_order_conversation

    render json: {
      conversation_id: @conversation.display_id,
      auth_token: ::Widget::TokenService.new(payload: { source_id: @contact_inbox.source_id, inbox_id: inbox.id }).generate_token
    }
  end

  private

  def inbox
    @web_widget.inbox
  end

  def validate_hmac
    identifier, identifier_hash = params.require(%i[identifier identifier_hash])
    expected_hash = OpenSSL::HMAC.hexdigest('sha256', @web_widget.hmac_token, identifier.to_s)
    return if ActiveSupport::SecurityUtils.secure_compare(identifier_hash.to_s, expected_hash)

    render json: { error: 'HMAC failed: Invalid Identifier Hash Provided' }, status: :unauthorized
  end

  def verified_contact_inboxes(contact)
    contact.contact_inboxes.where(inbox: inbox, hmac_verified: true)
  end

  def verified_contact_inbox
    contact = inbox.account.contacts.find_by(identifier: permitted_params[:identifier])
    verified_contact_inboxes(contact).last if contact
  end

  def build_verified_contact_inbox
    ContactInboxWithContactBuilder.new(
      inbox: inbox,
      hmac_verified: true,
      contact_attributes: { identifier: permitted_params[:identifier], name: permitted_params[:name] }
    ).perform
  end

  # Only conversations on verified contact inboxes are visible to the widget for an identified contact
  def open_order_conversation
    inbox.conversations
         .where(contact_inbox_id: verified_contact_inboxes(@contact_inbox.contact).select(:id))
         .where.not(status: :resolved)
         .where("conversations.custom_attributes ->> 'order_id' = ?", permitted_params[:order_id].to_s)
         .last
  end

  def create_order_conversation
    ::Conversation.create!(
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      contact_id: @contact_inbox.contact_id,
      contact_inbox_id: @contact_inbox.id,
      custom_attributes: { contact_reason: permitted_params[:contact_reason], order_id: permitted_params[:order_id] }
    )
  end

  def permitted_params
    params.permit(:website_token, :identifier, :identifier_hash, :name, :contact_reason, :order_id)
  end
end
