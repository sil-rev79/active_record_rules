# frozen_string_literal: true

require "active_record"
require "active_record_rules/condition"
require "active_record_rules/condition_match"
require "active_record_rules/extractor"
require "active_record_rules/parse"
require "active_record_rules/rule"
require "active_record_rules/rule_match"
require "active_record_rules/railtie" if defined?(Rails)

# A production rule system for ActiveRecord objects.
#
# Rules are defined using a DSL which looks like this:
#
# @example Define a simple rule#
#   ActiveRecordRules.define_rule(<<~RULE)
#     rule Update number of posts for user
#       Post(<author_id>, status = "published")
#       User(id = <author_id>)
#     on match
#       User.find(author_id).increment!(:post_count)
#     on unmatch
#       User.find(author_id).decrement!(:post_count)
#   RULE
#
# Rules are persisted as database values (see
# ActiveRecordRules::Rule), and can be modified as part of a running
# system.
module ActiveRecordRules
  cattr_accessor :logger, :execution_context
  # We default to the SQLite dialect, but we also support :postgres
  cattr_accessor :dialect, default: :sqlite
  cattr_accessor :id_type, default: "integer"
  cattr_reader :automatic_load_paths

  def self.config = (yield self)

  def self.load_after_migration(*path_patterns)
    @automatic_load_paths = path_patterns
  end

  class << self
    def load_rules(*filenames, trigger_matches: false, trigger_unmatches: false)
      # Flatten any arrays in the arguments
      filenames = filenames.flat_map { _1.is_a?(Array) ? _1 : [_1] }

      definition_hashes = filenames.flat_map do |filename|
        File.open(filename) do |file|
          Parse.definitions(file.read).map do |definition|
            { definition.name => [definition, filename] }
          end
        end
      end

      definitions = definition_hashes.reduce({}) do |left, right|
        left.merge(right) do |key, (l, lfilename), (r, rfilename)|
          lloc = "#{lfilename}:#{l[:name].line}"
          rloc = "#{rfilename}:#{r[:name].line}"
          raise "Multiple definitions with same rule name: #{key}, #{lloc} and #{rloc}"
        end
      end

      definitions.each do |name, (definition, _)|
        if (rule = Rule.find_by(name: name))
          raw_update_rule(rule, definition, trigger_matches: trigger_matches, trigger_unmatches: trigger_unmatches)
        else
          raw_define_rule(definition, trigger_rules: trigger_matches)
        end
      end
      Rule.where.not(name: definitions.keys).each do |rule|
        raw_delete_rule(rule, trigger_rules: trigger_unmatches, cleanup: false)
      end

      cleanup_conditions

      definitions.keys
    end

    def define_rule(definition_string, trigger_rules: true)
      definition = Parse.definition(definition_string)
      raw_define_rule(definition, trigger_rules: trigger_rules)
    end

    def delete_rule(rule_name, trigger_rules: true)
      rule = Rule.find_by(name: rule_name)
      raw_delete_rule(rule, trigger_rules: trigger_rules, cleanup: true)
    end

    def trigger_all(*klasses)
      conditions = if klasses.empty?
                     Condition.all
                   else
                     klasses.reduce(Condition.none) do |relation, klass|
                       relation.or(Condition.for_class(klass))
                     end
                   end
      rules = Rule.joins(:conditions).where(conditions: { id: conditions }).distinct

      ActiveRecord::Base.transaction do
        conditions.each(&:activate)
        rules.each(&:activate)
        conditions.each(&:cleanup)
        rules.where(id: RuleMatch.where.not(awaiting_execution: nil).select("rule_id"))
             .each(&:run_pending_executions)
      end
    end

    def trigger(all_objects)
      ActiveRecord::Base.transaction do
        groups = all_objects.group_by(&:class)
        conditions = groups.keys.index_with { Condition.for_class(_1).includes_for_activate }

        rules_to_activate = Hash.new do |h, k|
          h[k] = Hash.new { _1[_2] = [] }
        end

        groups.each do |klass, objects|
          conditions[klass].each do |condition|
            condition.activate(ids: objects.pluck(:id)).each do |rule, keys_to_ids|
              keys_to_ids.each do |key, ids|
                rules_to_activate[rule][key] += ids
              end
            end
          end
        end

        rules = Rule.find(rules_to_activate.keys).index_by(&:id)
        rules_to_activate.each do |rule_id, keys_to_ids|
          rules[rule_id].activate(keys_to_ids)
        end

        groups.each do |klass, objects|
          conditions[klass].each do |condition|
            condition.cleanup(ids: objects.pluck(:id))
          end
        end

        rules.each_value(&:run_pending_executions)
      end
    end

    private

    def build_rule(definition)
      new_conditions = []

      extractors, constraints = definition.constraints.each_with_index.map do |constraint, index|
        next [nil, constraint] if constraint.is_a?(Parse::Ast::Comparison)

        constant_clauses = constraint.only_simple_clauses.clauses

        # first, try to find the condition in the conditions that we are already creating.
        condition = new_conditions.find do |c|
          c.match_class_name == constraint.class_name &&
            c.match_conditions == { "clauses" => constant_clauses.map(&:unparse) }
        end
        unless condition
          # If we fail there, then fall back to checking the database,
          # or creating a new one.
          condition = Condition.find_or_initialize_by(
            match_class_name: constraint.class_name,
            # We have to wrap the conditions in this fake object
            # because querying with an array at the toplevel turns
            # into an ActiveRecord IN query, which ruins everything.
            # Using an object here simplifies things a lot.
            match_conditions: { "clauses" => constant_clauses.map(&:unparse) }
          )
          condition.validate!
          new_conditions << condition unless condition.persisted?
        end

        extractor = Extractor.new(
          condition: condition,
          # We have to wrap the fields in this fake object because
          # querying with an array at the toplevel turns into an
          # ActiveRecord IN query, which ruins everything.  Using an
          # object here simplifies things a lot.
          fields: { "names" => constraint.record_names },
          key: "cond#{index + 1}",
          negated: constraint.negated
        )
        extractor.validate!

        [extractor, constraint.only_complex_clauses]
      end.transpose

      [
        Rule.new(
          extractors: extractors.compact,
          name: definition.name,
          variable_conditions: constraints.map { "  #{_1.unparse}\n" }.join,
          on_match: definition.on_match,
          on_update: definition.on_update,
          on_unmatch: definition.on_unmatch
        ),
        new_conditions
      ]
    end

    def raw_define_rule(definition, trigger_rules:)
      rule, new_conditions = build_rule(definition)

      rule.save!
      new_conditions.each(&:activate)
      rule.activate

      if trigger_rules
        rule.run_pending_executions
      else
        rule.ignore_pending_executions
      end

      rule
    end

    def rules_equal?(left, right)
      left.attributes.without("id") == right.attributes.without("id") &&
        left.extractors.length == right.extractors.length &&
        left.extractors.zip(right.extractors).all? { extractors_equal?(_1, _2) }
    end

    def extractors_equal?(left, right)
      left.key == right.key &&
        left.fields.to_set == right.fields.to_set &&
        conditions_equal?(left.condition, right.condition)
    end

    def conditions_equal?(left, right)
      left.match_class_name == right.match_class_name &&
        left.match_conditions == right.match_conditions
    end

    def raw_update_rule(rule, definition, trigger_matches:, trigger_unmatches:)
      new_rule, = build_rule(definition)

      return rule if rules_equal?(rule, new_rule)

      raw_delete_rule(rule, trigger_rules: trigger_unmatches, cleanup: false)
      rule = raw_define_rule(definition, trigger_rules: trigger_matches)

      cleanup_conditions

      rule
    end

    def raw_delete_rule(rule, trigger_rules:, cleanup:)
      if trigger_rules
        rule.unmatch_all
        rule.run_pending_executions
      end
      rule.destroy!

      cleanup_conditions if cleanup

      rule
    end

    def cleanup_conditions
      Condition
        .where("not exists(select 1 from arr__extractors where arr__extractors.condition_id = arr__conditions.id)")
        .destroy_all
    end
  end
end
