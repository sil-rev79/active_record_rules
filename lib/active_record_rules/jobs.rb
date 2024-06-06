# frozen_string_literal: true

require "active_job"

module ActiveRecordRules
  module Jobs
    class ActivateRules < ActiveJob::Base
      def perform(change)
        ids = ActiveRecordRules.activate_rules(change)
        ids.each { RunPendingExecutions.perform_later(_1) }
      end
    end

    class RunPendingExecutions < ActiveJob::Base
      def perform(id)
        ActiveRecordRules.run_pending_execution(id)
      end
    end
  end
end
