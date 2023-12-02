# frozen_string_literal: true

module ActiveRecordRules
  # A representation of a production rule which matches objects
  # matching conditions and runs code when the rule begins to match or
  # ceases to match.
  #
  # See +Condition+ for a depiction of how this class relates to the
  # conditions. The broad idea is that Condition is responsible for
  # "simple" things (i.e. checks against constant values) and the Rule
  # is responsible for "complex" things (i.e. checks involving
  # multiple objects).
  #
  # A Rule is provided updates by its related Condition nodes whenever
  # an object passes, or ceases to pass, its test. This allows for
  # incremental updates to the output.
  #
  # A Rule finds the other objects to process by looking into its
  # conditions' ConditionActivation objects to find the objects which
  # currently match the condition.
  class Rule < ActiveRecord::Base
    self.table_name = :arr__rules

    has_many :condition_rules
    has_many :conditions, through: :condition_rules
    has_many :rule_activations

    class RuleSyntaxError < StandardError; end

    def self.define_rule(definition_string)
      definition = Parser.new.definition.parse(definition_string, reporter: Parslet::ErrorReporter::Deepest.new)

      condition_rules = definition[:conditions].each_with_index.map do |condition_definition, index|
        constant_conditions = (condition_definition[:parts] || []).map do |cond|
          case cond
          in { name:, op:, rhs: { string: } }
            "#{name} #{op} #{string.to_s.to_json}"
          in { name:, op:, rhs: { number: } }
            "#{name} #{op} #{number}"
          in { name:, op:, rhs: { boolean: } }
            "#{name} #{op} #{boolean}"
          else
            nil
          end
        end.compact

        ConditionRule.new(
          key: "cond#{index + 1}",
          condition: Condition.find_or_initialize_by(
            match_class: condition_definition[:class_name].to_s,
            # We have to wrap the conditions in this fake object
            # because querying with an array at the toplevel turns
            # into an ActiveRecord IN query, which ruins everything.
            # Using an object here simplifies things a lot.
            match_conditions: { "clauses" => constant_conditions }
          )
        )
      end

      Rule.create!(
        condition_rules: condition_rules,
        name: definition[:name].to_s,
        definition: definition_string
      )
    rescue Parslet::ParseFailed => e
      raise RuleSyntaxError, e.parse_failure_cause.ascii_tree
    end

    def activate(key, object)
      names, constraints, activation_code, deactivation_code = parse_definition

      other_values = condition_rules.reject { _1.key == key }.to_h do |join|
        where = [{ id: join.condition_activations.pluck(:entry_id) }]

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

        logger&.debug do
          "Rule(#{id}): checking constraints for #{ids.to_json}"
        end

        # Re-check constraints here, because the above only applied
        # filters for current object to each query table.
        # TODO: don't re-apply constraints that we already know hold
        matches = constraints.all? do |op, lhs, rhs|
          case [lhs, rhs]
          in [[lkey, lfield], [rkey, rfield]]
            lvalue = vals[lkey][lfield]
            rvalue = vals[rkey][rfield]
            result = lvalue.send(op, rvalue)
            logger&.debug do
              suffix = result ? "matches" : "does not match"
              real_values = "#{lvalue.inspect} #{op} #{rvalue.inspect}"
              symbolic_values = "#{lkey}.#{lfield} #{op} #{rkey}.#{rfield}"
              "Rule(#{id}): #{real_values} (#{symbolic_values}) #{suffix}"
            end
            result
          else
            # If the constraint doesn't match one of the above, then
            # just ignore it. It's a constant constraint, and thus has
            # been done by the Condition node.
            true
          end
        end

        next unless matches

        begin
          activation = rule_activations.create!(ids: ids, arguments: arguments)
          current_matches.add(activation.id)
          logger&.info { "Rule(#{id}): activated for #{ids.to_json}" }
          logger&.debug { "Rule(#{id}): activated with arguments #{arguments.to_json}" }

          Object.new.instance_exec(*arguments, &activation_code)
        rescue ActiveRecord::RecordNotUnique => e
          # TODO: expand beyond just SQLite
          raise e unless e.message.start_with?("SQLite3::ConstraintException: UNIQUE constraint failed")

          activation = rule_activations.find_by(ids: ids)
          current_matches.add(activation.id)
          activation_arguments = activation.arguments
          if arguments == activation_arguments
            logger&.debug do
              "Rule(#{id}): still matches for #{ids.to_json}"
            end
          else
            logger&.info { "Rule(#{id}): reactivated for #{ids.to_json}" }
            logger&.debug { "Rule(#{id}): reactivated with arguments #{arguments.to_json}" }

            Object.new.instance_exec(*activation_arguments, &deactivation_code)
            activation.update!(arguments: arguments)

            Object.new.instance_exec(*arguments, &activation_code)
          end
        end
      end

      # Clean up any existing activations that are no longer current.
      # Essentially: if we didn't see it on our most recent pass
      # through then it needs to be destroyed.
      rule_activations.where("ids->>? = ?", key, object.id).where.not(id: current_matches).destroy_all.each do |record|
        logger&.info do
          "Rule(#{id}): deactivated for #{record.ids.to_json} (set no longer matches rule)"
        end
        Object.new.instance_exec(*record.arguments, &deactivation_code)
      end
    rescue Parslet::ParseFailed => e
      raise e.parse_failure_cause.ascii_tree
    end

    def deactivate(key, object)
      destroyed = rule_activations.destroy_by("ids->>? = ?", key, object.id)

      _, _, _, deactivation_code = parse_definition

      destroyed.each do |record|
        logger&.info do
          "Rule(#{id}): deactivated for #{record.ids.to_json} (entry removed by condition)"
        end

        Object.new.instance_exec(*record.arguments, &deactivation_code)
      end
    end

    private

    def logger
      ActiveRecordRules.logger
    end

    def parse_definition
      parsed = Parser.new.definition.parse(definition, reporter: Parslet::ErrorReporter::Deepest.new)

      names = Hash.new { _1[_2] = [] }

      constraints = Set.new

      parsed[:conditions].each_with_index.map do |condition_definition, index|
        condition_definition[:parts].each do |cond|
          case cond
          in { name:, op: "=", rhs: { name: rhs } }
            names[rhs.to_s] << ["cond#{index + 1}", name.to_s]
          in { name:, op:, rhs: { number: rhs } }
            constraints << [op, ["cond#{index + 1}", name.to_s], rhs.to_i]
          in { name:, op:, rhs: { string: rhs } }
            constraints << [op, ["cond#{index + 1}", name.to_s], rhs.to_s]
          in { name:, op:, rhs: { boolean: rhs } }
            constraints << [op, ["cond#{index + 1}", name.to_s], rhs.to_s == "true"]
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
end
