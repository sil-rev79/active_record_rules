# frozen_string_literal: true

module ActiveRecordRules
  class ConditionMemory < ActiveRecord::Base
    belongs_to :condition
  end
end
