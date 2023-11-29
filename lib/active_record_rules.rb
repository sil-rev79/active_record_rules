# frozen_string_literal: true

require "active_record_rules/parser"

module ActiveRecordRules
  module Fact
    def self.included(klass)
      klass.instance_eval do
        after_commit do |object|
          transaction do
            ActiveRecordRules.trigger_rule_updates(object)
          end
        end
      end
    end
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
      clauses = JSON.parse(condition.match_conditions)
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

  class Condition < ActiveRecord::Base
    has_many :condition_rules
    has_many :condition_memories
    has_many :rules, through: :condition_rules
    validates :match_class, presence: true
  end

  class ConditionMemory < ActiveRecord::Base
    belongs_to :condition
  end

  class ConditionRule < ActiveRecord::Base
    belongs_to :condition
    has_many :condition_memories, through: :condition
    belongs_to :rule
    validates :key, uniqueness: { scope: :rule }
  end

  class Rule < ActiveRecord::Base
    has_many :condition_rules
    has_many :conditions, through: :condition_rules
    has_many :rule_memories

    def self.create_from_definition(definition_string)
      definition = Parser.new.definition.parse(definition_string, reporter: Parslet::ErrorReporter::Deepest.new)

      condition_rules = definition[:conditions].each_with_index.map do |condition_definition, index|
        constant_conditions = condition_definition[:parts].map do |cond|
          case cond
          in { name:, op:, rhs: { number: } }
            "#{name} = #{number}"
          in { name:, op:, rhs: { string: } }
            "#{name} = #{string.to_s.to_json}"
          else
            nil
          end
        end.compact

        ConditionRule.new(
          key: "cond#{index + 1}",
          condition: Condition.find_or_initialize_by(
            match_class: condition_definition[:class_name].to_s,
            match_conditions: constant_conditions.to_json
          )
        )
      end

      Rule.create!(
        condition_rules: condition_rules,
        name: definition[:name].to_s,
        definition: definition_string
      )
    rescue Parslet::ParseFailed => e
      raise e.parse_failure_cause.ascii_tree
    end

    def activate(key, object)
      names, constraints, activation_code, deactivation_code = parse_definition

      other_values = condition_rules.reject { _1.key == key }.to_h do |join|
        where = [{ id: join.condition_memories.pluck(:entry_id) }]

        join_key = join.key

        constraints.each do |op, lhs, rhs|
          case [lhs, rhs]
          in [[^key, left_field], [^join_key, right_field]]
            where << ["? #{op} #{right_field}", object[left_field]]
          in [[^join_key, left_field], [^key, right_field]]
            where << ["#{left_field} #{op} ?", object[right_field]]
          else
            # If the constraint doesn't match one of the above, then
            # just ignore it. It's either a constant (and thus has
            # been done by the Condition node), or it's not relevant
            # to this specific table.
          end
        end

        [join.key,
         where.reduce(join.condition.match_class.constantize, &:where)]
      end

      current_matches = Set.new

      keys = [key, *other_values.keys]
      [object].product(*other_values.values).each do |objects|
        vals = keys.zip(objects).sort_by(&:first).to_h
        ids = vals.transform_values(&:id)
        arguments = names.values.map(&:first).map { vals[_1][_2] }

        # Re-check constraints here, because the above only applied
        # filters for current object to each query table.
        # TODO: don't re-apply constraints that we already know hold
        matches = constraints.all? do |op, lhs, rhs|
          case [lhs, rhs]
          in [[lkey, lfield], [rkey, rfield]]
            vals[lkey][lfield].send(op, vals[rkey][rfield])
          else
            # If the constraint doesn't match one of the above, then
            # just ignore it. It's a constant constraint, and thus has
            # been done by the Condition node.
            true
          end
        end

        next unless matches

        begin
          memory = rule_memories.create!(
            cached: ids.to_json,
            arguments: arguments.to_json # TODO: serialize better?
          )
          current_matches.add(memory.id)

          Object.new.instance_exec(*arguments, &activation_code)
        rescue ActiveRecord::RecordNotUnique => e
          # TODO: expand beyond just SQLite
          raise e unless e.message.start_with?("SQLite3::ConstraintException: UNIQUE constraint failed")

          memory = rule_memories.find_by(cached: ids.to_json)
          current_matches.add(memory.id)
          memory_arguments = JSON.parse(memory.arguments)
          if arguments != memory_arguments
            Object.new.instance_exec(*memory_arguments, &deactivation_code)
            memory.update!(arguments: arguments.to_json)

            Object.new.instance_exec(*arguments, &activation_code)
          end
        end
      end

      # Clean up any existing memories that are no longer current.
      # Essentially: if we didn't see it on our most recent pass
      # through then it needs to be destroyed.
      rule_memories.where.not(id: current_matches).destroy_all.each do |record|
        Object.new.instance_exec(*JSON.parse(record.arguments), &deactivation_code)
      end
    rescue Parslet::ParseFailed => e
      raise e.parse_failure_cause.ascii_tree
    end

    def deactivate(key, object)
      destroyed = rule_memories.destroy_by("cached->>? = ?", key, object.id)

      _, _, _, deactivation_code = parse_definition

      destroyed.each do |record|
        Object.new.instance_exec(*JSON.parse(record.arguments), &deactivation_code)
      end
    end

    private

    def parse_definition
      parsed = Parser.new.definition.parse(definition, reporter: Parslet::ErrorReporter::Deepest.new)

      names = Hash.new { _1[_2] = [] }

      constraints = Set.new

      parsed[:conditions].each_with_index.map do |condition_definition, index|
        condition_definition[:parts].each do |cond|
          case cond
          in { name:, op: "=", rhs: { name: rhs } }
            names[rhs.to_s] << ["cond#{index + 1}", name.to_s]
          in { name:, op:, rhs: { string: rhs } }
            constraints << [op, ["cond#{index + 1}", name.to_s], rhs.to_s]
          in { name:, op:, rhs: { number: rhs } }
            constraints << [op, ["cond#{index + 1}", name.to_s], rhs.to_i]
          in { name:, op:, rhs: { name: rhs } }
            fields = names[rhs.to_s]
            raise "Right-hand side name does not have a value in constraint: #{name} #{op} #{fields}" if fields.empty?

            fields.each do |field|
              constraints << [op, ["cond#{index + 1}", name.to_s], field]
            end
          in { name: }
            names[name.to_s] << ["cond#{index + 1}", name.to_s]
          else
            raise "Unknown constraint format: #{cond}"
          end
        end
      end

      names.each_value do |fields|
        fields[1..].zip(fields).each do |lhs, rhs|
          constraints << ["==", lhs, rhs]
        end
      end

      activation_code = Object.new.instance_eval(<<~RUBY, __FILE__, __LINE__ + 1)
        # ->(in1, in2) {
        #   puts "Activating for \#{in1} \#{in2}"
        # }

        ->(#{names.keys.join(", ")}) {
          #{parsed[:activation]&.pluck(:line)&.join("\n  ")}
        }
      RUBY

      deactivation_code = Object.new.instance_eval(<<~RUBY, __FILE__, __LINE__ + 1)
        # ->(in1, in2) {
        #   puts "Deactivating for \#{in1} \#{in2}"
        # }

        ->(#{names.keys.join(", ")}) {
          #{parsed[:deactivation]&.pluck(:line)&.join("\n  ")}
        }
      RUBY

      [names, constraints, activation_code, deactivation_code]
    end
  end

  class RuleMemory < ActiveRecord::Base
    belongs_to :rule
  end
end
