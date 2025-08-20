# frozen_string_literal: true

module ActiveRecordRules
  module Hooks
    def self.included(klass)
      klass.after_create do
        if (change = ActiveRecordRules.capture_create_change(self))
          ActiveRecordRules.activate_and_execute(change, :after_save)

          pushed = Thread.current[:pending_active_record_rules_changes]&.push(change)

          ActiveRecord.after_all_transactions_commit do
            ActiveRecordRules.activate_and_execute(change, :after_request) unless pushed
            ActiveRecordRules.activate_and_execute(change, :after_commit)
            ActiveRecordRules.schedule_later_activation(change)
          end
        end
      end
      klass.after_update do
        if (change = ActiveRecordRules.capture_update_change(self))
          ActiveRecordRules.activate_and_execute(change, :after_save)

          pushed = Thread.current[:pending_active_record_rules_changes]&.push(change)

          ActiveRecord.after_all_transactions_commit do
            ActiveRecordRules.activate_and_execute(change, :after_request) unless pushed
            ActiveRecordRules.activate_and_execute(change, :after_commit)
            ActiveRecordRules.schedule_later_activation(change)
          end
        end
      end
      klass.after_destroy do
        if (change = ActiveRecordRules.capture_destroy_change(self))
          ActiveRecordRules.activate_and_execute(change, :after_save)

          pushed = Thread.current[:pending_active_record_rules_changes]&.push(change)

          ActiveRecord.after_all_transactions_commit do
            ActiveRecordRules.activate_and_execute(change, :after_request) unless pushed
            ActiveRecordRules.activate_and_execute(change, :after_commit)
            ActiveRecordRules.schedule_later_activation(change)
          end
        end
      end
    end
  end
end
