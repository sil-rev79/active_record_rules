# frozen_string_literal: true

module ActiveRecordRules
  # A simple condition which matches records by basic attribute. These
  # records are used as the entry point to the matching system.
  #
  # A single condition may be shared between multiple rules, through a
  # ConditionRule join record. Similarly, a single rule may have
  # multiple conditions. A typical example might look like this:
  #
  #  +---------------+  +------------------+
  #  | [Condition]   |  | [Condition]      |
  #  | class=User    |  | class=Post       |
  #  | status=active |  | status=published |
  #  +---------+-----+  +----+-------------+
  #      key:  |             | key:
  #      cond1 |             | cond2
  #            v             v
  #  +-------------------------------------+
  #  | [Rule]                              |
  #  | cond1.id = cond2.author_id          |
  #  | activate: decrement post count      |
  #  | deactivate: increment post count    |
  #  +---------------+---------------------+
  #
  class Condition < ActiveRecord::Base
    self.table_name = :arr__conditions

    has_many :condition_rules
    has_many :condition_activations
    has_many :rules, through: :condition_rules
    validates :match_class, presence: true
  end
end
