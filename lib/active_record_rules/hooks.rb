# frozen_string_literal: true

module ActiveRecordRules
  module Hooks
    def self.included(klass)
      klass.after_create do
        if (change = ActiveRecordRules.capture_create_change(self))
          @arr__transaction_changes ||= Set.new
          ActiveRecordRules.activate_and_execute(change, :after_save)
          @arr__transaction_changes << change
          Thread.current[:pending_active_record_rules_changes]&.push(change)
        end
      end
      klass.after_update do
        if (change = ActiveRecordRules.capture_update_change(self))
          @arr__transaction_changes ||= Set.new
          ActiveRecordRules.activate_and_execute(change, :after_save)
          @arr__transaction_changes << change
          Thread.current[:pending_active_record_rules_changes]&.push(change)
        end
      end
      klass.after_destroy do
        if (change = ActiveRecordRules.capture_destroy_change(self))
          @arr__transaction_changes ||= Set.new
          ActiveRecordRules.activate_and_execute(change, :after_save)
          @arr__transaction_changes << change
          Thread.current[:pending_active_record_rules_changes]&.push(change)
        end
      end

      # Then schedule the rule firings after the transaction commits.
      klass.after_commit do
        @arr__transaction_changes&.each do |change|
          ActiveRecordRules.activate_and_execute(change, :after_commit)
          unless Thread.current[:pending_active_record_rules_changes]
            ActiveRecordRules.activate_and_execute(change, :after_request)
          end
          ActiveRecordRules.schedule_later_activation(change)
        end
      ensure
        @arr__transaction_changes = nil
      end

      klass.after_rollback do
        # If the transaction rolls back, then remove all the changes
        # we made. We don't want them any more!
        @arr__transaction_changes = nil
      end
    end
  end
end
