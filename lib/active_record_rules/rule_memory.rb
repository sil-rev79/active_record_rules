# frozen_string_literal: true

module ActiveRecordRules
  class RuleMemory < ActiveRecord::Base
    belongs_to :rule
  end
end
