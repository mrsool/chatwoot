# Unassigns an agent's open/pending chats after they go Away or Offline and hands them back to auto-assignment.
class Fazaa::RequeueOnAwayJob < ApplicationJob
  queue_as :high

  def perform(account_id, user_id)
    account_user = AccountUser.find_by(account_id: account_id, user_id: user_id)
    return if account_user.blank? || %w[online busy].include?(account_user.availability)

    Current.executed_by = nil
    Conversation.where(account_id: account_id, assignee_id: user_id, status: [:open, :pending]).find_each do |conversation|
      requeue(conversation, account_user)
    end
  end

  private

  def requeue(conversation, account_user)
    Conversations::AssignmentService.new(conversation: conversation, assignee_id: nil).perform
    conversation.fazaa_post_requeue_note(account_user)
    conversation.fazaa_reassign_after_requeue!
  end
end
