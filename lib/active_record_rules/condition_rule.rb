# frozen_string_literal: true

module ActiveRecordRules
  # A join between Condition and Rules. Each ConditionRule also has a
  # key which is used to refer to the objects matching it when rule
  # constraints are checked.
  class ConditionRule < ActiveRecord::Base
    self.table_name = :arr__condition_rules

    belongs_to :condition
    has_many :condition_activations, through: :condition
    belongs_to :rule
    validates :key, uniqueness: { scope: :rule }
  end
end
