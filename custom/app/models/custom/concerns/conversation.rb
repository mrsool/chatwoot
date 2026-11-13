module Custom::Concerns::Conversation
  extend ActiveSupport::Concern

  FAZAA_ABSENT_AVAILABILITIES = %w[away offline].freeze
  FAZAA_REOPENED_FROM = %w[snoozed resolved].freeze

  included do
    # Prepended so it runs before AutoAssignmentHandler#run_legacy_auto_assignment in the same save.
    before_save :fazaa_unassign_absent_assignee_on_reopen, prepend: true, if: :fazaa_reopening_with_assignee?
  end

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

  private

  def fazaa_reopening_with_assignee?
    persisted? && will_save_change_to_status? && open? && FAZAA_REOPENED_FROM.include?(status_in_database) &&
      assignee_id.present? && !will_save_change_to_assignee_id?
  end

  # Spec §5.3: no chat sits with an absent assignee. Clearing the assignee lets upstream auto-assignment pick it up.
  def fazaa_unassign_absent_assignee_on_reopen
    return unless account.feature_enabled?('fazaa_wfm')

    availability = AccountUser.where(account_id: account_id, user_id: assignee_id).pick(:availability)
    self.assignee_id = nil if FAZAA_ABSENT_AVAILABILITIES.include?(availability)
  end
end
