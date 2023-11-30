# frozen_string_literal: true

module ActiveRecordRules
  class ConditionMemory < ActiveRecord::Base
    self.table_name = :arr__condition_memories

    belongs_to :condition
  end
end
