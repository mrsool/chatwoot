module Custom::Concerns::Conversation
  extend ActiveSupport::Concern

  def fazaa_post_requeue_note(account_user)
    reason_name = account_user.away_reason&.name
    content = I18n.t(
      'conversations.activity.assignee.requeued_on_away',
      agent_name: account_user.user.name,
      status: I18n.t("conversations.activity.assignee.requeued_status.#{account_user.availability}"),
      reason: reason_name.present? ? ": #{reason_name}" : ''
    )
    messages.create!(activity_message_params(content))
  end

  # Mirrors AutoAssignmentHandler#run_auto_assignment for a conversation that has just been unassigned.
  def fazaa_reassign_after_requeue!
    return unless inbox.enable_auto_assignment?

    if inbox.auto_assignment_v2_enabled?
      AutoAssignment::AssignmentJob.enqueue_for_inbox(inbox.id)
    else
      AutoAssignment::AgentAssignmentService.new(conversation: self, allowed_agent_ids: legacy_allowed_agent_ids).perform
    end
  end
end
