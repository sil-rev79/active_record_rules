# frozen_string_literal: true

module ActiveRecordRules
  class ConditionActivation < ActiveRecord::Base
    self.table_name = :arr__condition_activations

    belongs_to :condition
  end
end
