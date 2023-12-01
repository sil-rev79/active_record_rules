# frozen_string_literal: true

module ActiveRecordRules
  class RuleActivation < ActiveRecord::Base
    self.table_name = :arr__rule_activations

    belongs_to :rule
  end
end
