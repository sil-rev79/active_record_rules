# frozen_string_literal: true

module ActiveRecordRules
  module Hooks
    module AfterSave
      def self.included(klass)
        klass.after_create { ActiveRecordRules.after_create_trigger(self) }
        klass.after_update { ActiveRecordRules.after_update_trigger(self) }
        klass.after_destroy { ActiveRecordRules.after_destroy_trigger(self) }
      end
    end

    module AfterCommit
      def self.included(klass)
        # Track changes that are made during a transaction.
        klass.after_create { (@arr__transaction_changes ||= []) << ActiveRecordRules.capture_create_change(self) }
        klass.after_update { (@arr__transaction_changes ||= []) << ActiveRecordRules.capture_update_change(self) }
        klass.after_destroy { (@arr__transaction_changes ||= []) << ActiveRecordRules.capture_destroy_change(self) }

        # Then schedule the rule firings after the transaction commits.
        klass.after_commit do
          @arr__transaction_changes.each { ActiveRecordRules.activate_and_execute(_1) }
        ensure
          @arr__transaction_changes = []
        end
      end
    end

    module Async
      def self.included(klass)
        # Track changes that are made during a transaction.
        klass.after_create { (@arr__transaction_changes ||= []) << ActiveRecordRules.capture_create_change(self) }
        klass.after_update { (@arr__transaction_changes ||= []) << ActiveRecordRules.capture_update_change(self) }
        klass.after_destroy { (@arr__transaction_changes ||= []) << ActiveRecordRules.capture_destroy_change(self) }

        # Then schedule the rule firings after the transaction commits.
        klass.after_commit do
          @arr__transaction_changes.each { ActiveRecordRules::Jobs::ActivateRules.perform_later(_1) }
        ensure
          @arr__transaction_changes = []
        end
      end
    end
  end
end
