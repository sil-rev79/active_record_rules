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

  # Internal state
  cattr_accessor :loaded_rules, default: []

  class << self
    def config = (yield self)

    def load_after_migration(*path_patterns)
      @automatic_load_paths = path_patterns
    end

    def load_rules(*filenames)
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
          raw_define_rule(definition)
        end
      end
      Rule.where.not(name: definitions.keys).each do |rule|
        raw_delete_rule(rule)
      end

      definitions.keys
    end

    def define_rule(definition_string)
      definition = Parse.definition(definition_string)
      raw_define_rule(definition)
    end

    def delete_rule(rule_name)
      rule = Rule.find_by(name: rule_name)
      raw_delete_rule(rule)
    end

    def trigger_all(*_klasses)
      ActiveRecord::Base.transaction do
        loaded_rules.each(&:activate)
        loaded_rules.each(&:run_pending_executions)
      end
    end

    def trigger(_all_objects)
      ActiveRecord::Base.transaction do
        loaded_rules.each(&:activate)
        loaded_rules.each(&:run_pending_executions)
      end
    end

    private

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
      loaded_rules << rule
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
      loaded_rules.delete(rule)
      rule.destroy!
    end
  end
end
