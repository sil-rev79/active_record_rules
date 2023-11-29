# frozen_string_literal: true

module ActiveRecordRules
  class Condition < ActiveRecord::Base
    has_many :condition_rules
    has_many :condition_memories
    has_many :rules, through: :condition_rules
    validates :match_class, presence: true
  end
end
