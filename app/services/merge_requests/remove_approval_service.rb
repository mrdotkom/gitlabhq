# frozen_string_literal: true

module MergeRequests
  class RemoveApprovalService < MergeRequests::BaseService
    # rubocop: disable CodeReuse/ActiveRecord
    def execute(merge_request)
      # paranoid protection against running wrong deletes
      return unless merge_request.id && current_user.id

      approval = merge_request.approvals.where(user: current_user)

      trigger_approval_hooks(merge_request) do
        next unless approval.destroy_all # rubocop: disable Cop/DestroyAll

        reset_approvals_cache(merge_request)
        create_note(merge_request)
      end
    end
    # rubocop: enable CodeReuse/ActiveRecord

    private

    def reset_approvals_cache(merge_request)
      merge_request.approvals.reset
    end

    def trigger_approval_hooks(merge_request)
      yield

      execute_hooks(merge_request, 'unapproved')
    end

    def create_note(merge_request)
      SystemNoteService.unapprove_mr(merge_request, current_user)
    end
  end
end

MergeRequests::RemoveApprovalService.prepend_if_ee('EE::MergeRequests::RemoveApprovalService')
