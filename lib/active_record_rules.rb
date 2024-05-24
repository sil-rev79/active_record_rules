# frozen_string_literal: true

require "active_record"
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

  class << self
    def config = (yield self)

    def load_after_migration(*path_patterns)
      @automatic_load_paths = path_patterns
    end

    def load_rules(*filenames)
      @loaded_rules ||= {}

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
          raw_update_rule(rule, definition)
        else
          rule = raw_define_rule(definition)
        end
        @loaded_rules[name] = rule
      end
      Rule.where.not(name: definitions.keys).each do |rule|
        raw_delete_rule(rule)
      end

      definitions.keys
    end

    def unload_all_rules!
      @loaded_rules = {}
    end

    def define_rule(definition_string)
      definition = Parse.definition(definition_string)
      raw_define_rule(definition)
    end

    def delete_rule(rule_name)
      rule = Rule.find_by(name: rule_name)
      raw_delete_rule(rule)
    end

    def after_create_trigger(record) = inline_activate(capture_create_change(record))

    def capture_create_change(record)
      [record.class.name, nil, record.attributes]
    end

    def after_update_trigger(record) = inline_activate(capture_update_change(record))

    def capture_update_change(record)
      [record.class.name,
       record.attributes.merge(record.previous_changes.transform_values(&:first)),
       record.attributes]
    end

    def after_destroy_trigger(record) = inline_activate(capture_destroy_change(record))

    def capture_destroy_change(record)
      [record.class.name, record.attributes, nil]
    end

    def activate_rules(change)
      class_name, previous, current = change
      klass = Object.const_get(class_name)
      @loaded_rules.flat_map do |_, rule|
        pending = rule.calculate_required_activations(klass, previous, current)
        if pending.any?
          rule.activate(pending)
        else
          []
        end
      end
    end

    def run_pending_executions(*ids)
      ids.each do |id|
        match = RuleMatch.find_by(id: id)
        next unless match # If the match doesn't exist, ignore it - it might have unmatched

        @loaded_rules[match.rule_id].run_pending_execution(match)
      end
    end

    def activate_all
      # This might generate a *lot* of ids to process!
      @loaded_rules.flat_map do |_, rule|
        rule.activate
      end
    end

    private

    def inline_activate(change)
      activate_rules(change).each { run_pending_executions(_1) }
    end

    def build_rule(definition)
      Rule.new(
        name: definition.name,
        definition: definition.unparse
      )
    end

    def raw_define_rule(definition)
      rule = build_rule(definition)
      rule.save!
      rule.activate
      rule.ignore_pending_executions
      rule
    end

    def rules_equal?(left, right)
      left.definition == right.definition
    end

    def raw_update_rule(rule, definition)
      new_rule, = build_rule(definition)

      return rule if rules_equal?(rule, new_rule)

      raw_delete_rule(rule)
      raw_define_rule(definition)
    end

    def raw_delete_rule(rule)
      @loaded_rules.delete(rule.id)
      rule.destroy!
    end
  end
end
