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

      matches = object.persisted? && clauses.all? do |clause|
        result = case parser.parse(clause)
                 in { name:, op: "=", rhs: { string: } }
                   object[name] == string
                 in { name:, op:, rhs: { string: } }
                   object[name].public_send(op, string)
                 in { name:, op: "=", rhs: { number: } }
                   object[name] == number.to_i
                 in { name:, op:, rhs: { number: } }
                   object[name].public_send(op, number.to_i)
                 in { name:, op: "=", rhs: { boolean: } }
                   object[name] == (boolean.to_s == "true")
                 in { name:, op:, rhs: { boolean: } }
                   object[name].public_send(op, boolean.to_s == "true")
                 else
                   true
                 end
        logger&.info do
          if result
            "Condition(#{id}): #{object.class}(#{object.id}) matches { #{clause} }"
          else
            "Condition(#{id}): #{object.class}(#{object.id}) does not match { #{clause} }"
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
            "Condition(#{id}): deactivated for #{object.class}(#{object.id}) - failed a condition check"
          else
            "Condition(#{id}): deactivated for #{object.class}(#{object.id}) - was deleted"
          end
        end

        condition_rules.each do |join|
          join.rule.deactivate(join.key, object)
        end
      end
    end
  end
end
