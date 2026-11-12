# Unassigns an agent's open/pending chats after they go Away or Offline and hands them back to auto-assignment.
# Each chat is re-checked under a row lock, so a chat resolved or reassigned since the enqueue, or already
# requeued by a concurrent job, is left alone; a failing chat is reported and the rest still run.
class Fazaa::RequeueOnAwayJob < ApplicationJob
  queue_as :high

  def perform(account_id, user_id)
    account_user = AccountUser.find_by(account_id: account_id, user_id: user_id)
    return if account_user.blank? || %w[online busy].include?(account_user.availability)

    Current.executed_by = nil
    requeued = Conversation.where(account_id: account_id, assignee_id: user_id, status: [:open, :pending]).find_each.count do |conversation|
      requeue(conversation, account_user)
    end
    log_requeue(account_user, requeued)
  end

  private

  def requeue(conversation, account_user)
    conversation.with_lock do
      next false unless conversation.assignee_id == account_user.user_id && (conversation.open? || conversation.pending?)

      Conversations::AssignmentService.new(conversation: conversation, assignee_id: nil).perform
      conversation.fazaa_post_requeue_note(account_user)
      conversation.fazaa_reassign_after_requeue!
      true
    end
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: account_user.account).capture_exception
    false
  end

  def log_requeue(account_user, requeued)
    changed_at = AgentAvailabilityEvent.where(account_id: account_user.account_id, user_id: account_user.user_id).maximum(:changed_at)
    latency_ms = changed_at ? ((Time.current - changed_at) * 1000).round : 'n/a'
    Rails.logger.info(
      "[fazaa.requeue] account=#{account_user.account_id} user=#{account_user.user_id} chats=#{requeued} latency_ms=#{latency_ms}"
    )
  end
end
