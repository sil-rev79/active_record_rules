# frozen_string_literal: true

module ActiveRecordRules
  # A mixin to indicate that an ActiveRecord model should take part in
  # the rule matching process.
  #
  # Rule updates are triggered in an after_commit callback, but within
  # their own transaction.
  module Fact
    def self.included(klass)
      klass.instance_eval do
        after_commit do |object|
          transaction do
            ActiveRecordRules.trigger_rule_updates(object)
          end
        end
      end
    end
  end
end
