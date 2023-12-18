# frozen_string_literal: true

require "active_record_rules/condition"
require "active_record_rules/condition_match"
require "active_record_rules/extractor"
require "active_record_rules/extractor_match"
require "active_record_rules/extractor_key"
require "active_record_rules/parser"
require "active_record_rules/rule"
require "active_record_rules/rule_match"

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

  def self.define_rule(definition_string, trigger_rules: true)
    definition = Parser.new.definition.parse(definition_string, reporter: Parslet::ErrorReporter::Deepest.new)

    extractor_keys = definition[:conditions].each_with_index.map do |condition_definition, index|
      constant_conditions = (condition_definition[:parts] || []).map do |cond|
        case cond
        in { name:, op:, rhs: { string: } }
          "#{name} #{op} #{string.to_s.to_json}"
        in { name:, op:, rhs: { number: } }
          "#{name} #{op} #{number}"
        in { name:, op:, rhs: { boolean: } }
          "#{name} #{op} #{boolean}"
        in { name:, op:, rhs: { nil: _ } }
          "#{name} #{op} nil"
        else
          nil
        end
      end.compact

      condition = Condition.find_or_initialize_by(
        match_class_name: condition_definition[:class_name].to_s,
        # We have to wrap the conditions in this fake object
        # because querying with an array at the toplevel turns
        # into an ActiveRecord IN query, which ruins everything.
        # Using an object here simplifies things a lot.
        match_conditions: { "clauses" => constant_conditions }
      )
      condition.validate!

      fields = (condition_definition[:parts] || [])
               .select { _1[:rhs].nil? || !_1[:rhs][:name].nil? } # remove the constant conditions
               .map { _1[:name].to_s }
               .uniq

      extractor = Extractor.find_or_initialize_by(
        condition: condition,
        # We have to wrap the fields in this fake object because
        # querying with an array at the toplevel turns into an
        # ActiveRecord IN query, which ruins everything.  Using an
        # object here simplifies things a lot.
        fields: { "names" => fields }
      )
      extractor.validate!

      ExtractorKey.new(
        extractor: extractor,
        key: "cond#{index + 1}"
      )
    end

    rule = Rule.create!(
      extractor_keys: extractor_keys,
      name: definition[:name].to_s,
      definition: definition_string
    )

    rule.conditions.each do |condition|
      condition.activate_all(trigger_rules: trigger_rules)
    end

    rule
  end

  def self.trigger_all(*klasses)
    conditions = if klasses.empty?
                   Condition.all
                 else
                   klasses.reduce(Condition.none) do |relation, klass|
                     relation.or(Condition.for_class(klass))
                   end
                 end
    ActiveRecord::Base.transaction do
      conditions.each(&:activate_all)
    end
  end

  def self.trigger(all_objects)
    ActiveRecord::Base.transaction do
      all_objects.group_by(&:class).each do |klass, objects|
        conditions = Condition.for_class(klass).includes_for_activate

        conditions.each do |condition|
          condition.activate(objects)
        end
      end
    end
  end
end
