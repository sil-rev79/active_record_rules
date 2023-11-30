# frozen_string_literal: true

module ActiveRecordRules
  class RuleMemory < ActiveRecord::Base
    self.table_name = :arr__rule_memories

    belongs_to :rule
  end
end
