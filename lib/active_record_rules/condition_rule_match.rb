# frozen_string_literal: true

module ActiveRecordRules
  # A record indicating an entry that meets a condition/rule combo.
  class ConditionRuleMatch < ActiveRecord::Base
    self.table_name = :arr__condition_rule_matches

    belongs_to :condition_rule
  end
end
