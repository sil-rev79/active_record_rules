# frozen_string_literal: true

module ActiveRecordRules
  class ConditionRule < ActiveRecord::Base
    self.table_name = :arr__condition_rules

    belongs_to :condition
    has_many :condition_activations, through: :condition
    belongs_to :rule
    validates :key, uniqueness: { scope: :rule }
  end
end
