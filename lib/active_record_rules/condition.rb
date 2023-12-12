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
  #  | on_match: decrement post count      |
  #  | on_unmatch: increment post count    |
  #  +---------------+---------------------+
  #
  class Condition < ActiveRecord::Base
    self.table_name = :arr__conditions

    has_many :condition_rules
    has_many :condition_matches
    has_many :rules, through: :condition_rules
    validates :match_class, presence: true
    validate :validate_fact_class

    scope :for_class, lambda { |c|
      where(match_class: c.ancestors.select { _1.included_modules.include?(ActiveRecordRules::Fact) }.map(&:name))
    }
    scope :includes_for_activate, -> { includes(condition_rules: { rule: { condition_rules: {} } }) }

    def activate(object)
      clauses = match_conditions["clauses"]
      parser = Parser.new.condition_part

      logger&.debug do
        "Condition(#{id}): checking #{object.class}(#{object.id})"
      end

      matches = object.persisted? && clauses.all? do |clause|
        lhs, op, rhs = case parser.parse(clause)
                       in { name:, op:, rhs: { string: } }
                         [object[name], (op == "=" ? "==" : op), string.to_s]
                       in { name:, op:, rhs: { number: } }
                         [object[name], (op == "=" ? "==" : op), number.to_i]
                       in { name:, op:, rhs: { boolean: } }
                         [object[name], (op == "=" ? "==" : op), (boolean.to_s == "true")]
                       in { name:, op:, rhs: { nil: _ } }
                         [object[name], (op == "=" ? "==" : op), nil]
                       else
                         raise "Non-constant test in Condition(#{id}): #{clause}"
                       end
        result = lhs.public_send(op, rhs)
        logger&.debug do
          if result
            "Condition(#{id}): #{lhs.inspect} #{op} #{rhs.inspect} (#{clause}) matches"
          else
            "Condition(#{id}): #{lhs.inspect} #{op} #{rhs.inspect} (#{clause}) does not match"
          end
        end
        result
      end

      if matches
        if condition_matches.exists?(entry_id: object.id)
          logger&.info { "Condition(#{id}): matched by #{object.class}(#{object.id}) (updated)" }
        else
          logger&.info { "Condition(#{id}): matched by #{object.class}(#{object.id}) (matched)" }
          condition_matches.create!(entry_id: object.id)
        end

        # We trigger the rules, even if we already knew about the
        # object, because the rule argument values might have
        # changed. In principle we could lift the argument field
        # information to the Condition to avoid this step, but that
        # could reduce the amount of Condition sharing we can
        # do. Another option would be to lift it to the ConditionRule
        # join, but that would then require remembering matches at the
        # ConditionRule level.
        condition_rules.each { _1.activate(object) }
      elsif condition_matches.destroy_by(entry_id: object.id).any?
        logger&.info do
          if object.persisted?
            "Condition(#{id}): unmatched for #{object.class}(#{object.id}) (ceased to match)"
          else
            "Condition(#{id}): unmatched for #{object.class}(#{object.id}) (deleted)"
          end
        end
        condition_rules.each { _1.deactivate(object) }
      end
    end

    private

    def logger
      ActiveRecordRules.logger
    end

    def validate_fact_class
      errors.add(:match_class, "must be a subclass of ActiveRecordRules::Fact") unless match_class.constantize < Fact
    end
  end
end
