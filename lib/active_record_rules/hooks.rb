# frozen_string_literal: true

module ActiveRecordRules
  module Hooks
    def self.included(klass)
      klass.after_create do
        @arr__transaction_changes ||= Set.new
        change = ActiveRecordRules.capture_create_change(self)
        ActiveRecordRules.activate_and_execute(change, :after_save)
        @arr__transaction_changes << change
      end
      klass.after_update do
        @arr__transaction_changes ||= Set.new
        change = ActiveRecordRules.capture_update_change(self)
        ActiveRecordRules.activate_and_execute(change, :after_save)
        @arr__transaction_changes << change
      end
      klass.after_destroy do
        @arr__transaction_changes ||= Set.new
        change = ActiveRecordRules.capture_destroy_change(self)
        ActiveRecordRules.activate_and_execute(change, :after_save)
        @arr__transaction_changes << change
      end

      # Then schedule the rule firings after the transaction commits.
      klass.after_commit do
        @arr__transaction_changes.each do |change|
          ActiveRecordRules.activate_and_execute(change, :after_commit)
          ActiveRecordRules.schedule_async_activation(change)
        end
      ensure
        @arr__transaction_changes = nil
      end
    end
  end
end
