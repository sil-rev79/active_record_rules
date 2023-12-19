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

  class << self
    def load_rules(*filenames, trigger_matches: false, trigger_unmatches: false)
      parser = Parser.new.definitions
      definition_hashes = filenames.flat_map do |filename|
        File.open(filename) do |file|
          parser.parse(file.read, reporter: Parslet::ErrorReporter::Deepest.new).map do |parsed|
            { parsed[:definition][:name].to_s => [parsed[:definition], filename] }
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

      definitions.each do |name, (definition, _filename)|
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
      cleanup_extractors

      definitions.keys
    end

    def define_rule(definition_string, trigger_rules: true)
      definition = Parser.new.definition.parse(definition_string, reporter: Parslet::ErrorReporter::Deepest.new)
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
      ActiveRecord::Base.transaction do
        conditions.each(&:activate_all)
      end
    end

    def trigger(all_objects)
      ActiveRecord::Base.transaction do
        all_objects.group_by(&:class).each do |klass, objects|
          conditions = Condition.for_class(klass).includes_for_activate

          conditions.each do |condition|
            condition.activate(objects)
          end
        end
      end
    end

    private

    def raw_define_rule(definition, trigger_rules:)
      new_conditions = []

      extractor_keys, condition_strings = definition[:conditions].each_with_index.map do |condition_definition, index|
        constant_clauses = (condition_definition[:parts] || []).map do |cond|
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

        variable_clauses = (condition_definition[:parts] || []).map do |cond|
          case cond
          in { name:, op:, rhs: { name: rhs } }
            "#{name} #{op} <#{rhs}>"
          in { name: }
            "<#{name}>"
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
          match_conditions: { "clauses" => constant_clauses }
        )
        condition.validate!
        new_conditions << condition unless condition.persisted?

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

        [
          ExtractorKey.new(
            extractor: extractor,
            key: "cond#{index + 1}"
          ),
          "#{condition_definition[:class_name]}(#{variable_clauses.join(", ")})"
        ]
      end.transpose

      rule = Rule.create!(
        extractor_keys: extractor_keys,
        name: definition[:name].to_s,
        variable_conditions: condition_strings.map { "  #{_1}\n" }.join,
        on_match: definition[:on_match]&.pluck(:line)&.join("\n  "),
        on_update: definition[:on_update]&.pluck(:line)&.join("\n  "),
        on_unmatch: definition[:on_unmatch]&.pluck(:line)&.join("\n  ")
      )

      new_conditions.each do |condition|
        condition.activate_all(trigger_rules: trigger_rules)
      end

      rule
    end

    def raw_update_rule(rule, definition, trigger_matches:, trigger_unmatches:)
      raw_delete_rule(rule, trigger_rules: trigger_unmatches, cleanup: false)
      rule = raw_define_rule(definition, trigger_rules: trigger_matches)

      cleanup_extractors
      cleanup_conditions

      rule
    end

    def raw_delete_rule(rule, trigger_rules:, cleanup:)
      rule.unmatch_all if trigger_rules
      rule.destroy!

      unless cleanup
        cleanup_extractors
        cleanup_conditions
      end

      rule
    end

    def cleanup_extractors
      empty_extractors = Extractor.joins(:extractor_keys)
                                  .group(:id)
                                  .having(Arel.sql("count").eq(0))
                                  .pluck(:id, "count(arr__extractor_keys.id) as count")
      Extractor.where(id: empty_extractors).destroy_all unless empty_extractors.empty?
    end

    def cleanup_conditions
      empty_conditions = Condition.joins(:extractors)
                                  .group(:id)
                                  .having(Arel.sql("count").eq(0))
                                  .pluck(:id, "count(arr__extractors.id) as count")
      Condition.where(id: empty_conditions).destroy_all unless empty_conditions.empty?
    end
  end
end
