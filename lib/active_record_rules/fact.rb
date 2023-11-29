# frozen_string_literal: true

module ActiveRecordRules
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
