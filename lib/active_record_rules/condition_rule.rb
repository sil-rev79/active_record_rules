# frozen_string_literal: true

module ActiveRecordRules
  class ConditionRule < ActiveRecord::Base
    belongs_to :condition
    has_many :condition_memories, through: :condition
    belongs_to :rule
    validates :key, uniqueness: { scope: :rule }
  end
end
