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
        logger&.info { "Condition(#{id}): activated by #{object.class}(#{object.id})" }
        begin
          condition_activations.create(entry_id: object.id)
        rescue ActiveRecord::RecordNotUnique => e
          raise e unless e.message.start_with?("SQLite3::ConstraintException: UNIQUE constraint failed")
        end

        condition_rules.each do |join|
          join.rule.activate(join.key, object)
        end
      elsif condition_activations.destroy_by(entry_id: object.id).any?
        logger&.info do
          if object.persisted?
            "Condition(#{id}): deactivated for #{object.class}(#{object.id}) (ceased to match)"
          else
            "Condition(#{id}): deactivated for #{object.class}(#{object.id}) (deleted)"
          end
        end

        condition_rules.each do |join|
          join.rule.deactivate(join.key, object)
        end
      end
    end

    private

    def logger
      ActiveRecordRules.logger
    end
  end
end
