# frozen_string_literal: true

require "active_record_rules/condition"
require "active_record_rules/condition_memory"
require "active_record_rules/condition_rule"
require "active_record_rules/fact"
require "active_record_rules/parser"
require "active_record_rules/rule"
require "active_record_rules/rule_memory"

module ActiveRecordRules
  cattr_accessor :logger

  def self.define_rule(string)
    ActiveRecordRules::Rule.define_rule(string)
  end

  def self.trigger_rule_updates(object)
    klass = object.class
    classes = []
    while klass < Fact
      classes << klass
      klass = klass.superclass
    end
    Condition
      .where(match_class: classes.map(&:name))
      .includes(condition_rules: { rule: { condition_rules: {} } })
      .each do |condition|
      clauses = condition.match_conditions["clauses"]
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
            "Condition(#{condition.id}): #{object.class}(#{object.id}) matches { #{clause} }"
          else
            "Condition(#{condition.id}): #{object.class}(#{object.id}) does not match { #{clause} }"
          end
        end
        result
      end

      if matches
        logger&.info { "Condition(#{condition.id}): activated by #{object.class}(#{object.id})" }
        begin
          condition.condition_memories.create(entry_id: object.id)
        rescue ActiveRecord::RecordNotUnique => e
          raise e unless e.message.start_with?("SQLite3::ConstraintException: UNIQUE constraint failed")
        end

        condition.condition_rules.each do |join|
          join.rule.activate(join.key, object)
        end
      elsif condition.condition_memories.destroy_by(entry_id: object.id).any?
        logger&.info do
          if object.persisted?
            "Condition(#{condition.id}): deactivated for #{object.class}(#{object.id}) - failed a condition check"
          else
            "Condition(#{condition.id}): deactivated for #{object.class}(#{object.id}) - was deleted"
          end
        end

        condition.condition_rules.each do |join|
          join.rule.deactivate(join.key, object)
        end
      end
    end
  end
end
