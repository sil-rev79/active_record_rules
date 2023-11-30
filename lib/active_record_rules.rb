# frozen_string_literal: true

require "active_record_rules/condition"
require "active_record_rules/condition_memory"
require "active_record_rules/condition_rule"
require "active_record_rules/fact"
require "active_record_rules/parser"
require "active_record_rules/rule"
require "active_record_rules/rule_memory"

module ActiveRecordRules
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
      clauses = condition.match_conditions
      parser = Parser.new.condition_part

      matches = clauses.map { parser.parse(_1) }.all? do |clause|
        case clause
        in { name:, op: "=", rhs: { string: } }
          object[name] == string
        in { name:, op:, rhs: { string: } }
          object[name].public_send(op, string)
        in { name:, op: "=", rhs: { number: } }
          object[name] == number
        in { name:, op:, rhs: { number: } }
          object[name].public_send(op, number)
        else
          true
        end
      end

      if matches && object.persisted?
        begin
          condition.condition_memories.create(entry_id: object.id)
        rescue ActiveRecord::RecordNotUnique => e
          raise e unless e.message.start_with?("SQLite3::ConstraintException: UNIQUE constraint failed")
        end

        condition.condition_rules.each do |join|
          join.rule.activate(join.key, object)
        end
      elsif condition.condition_memories.destroy_by(entry_id: object.id)
        condition.condition_rules.each do |join|
          join.rule.deactivate(join.key, object)
        end
      end
    end
  end
end
