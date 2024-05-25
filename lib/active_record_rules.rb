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
module ActiveRecordRules
  cattr_accessor :execution_context

  class << self
    attr_accessor :execution_context
    attr_writer :logger, :dialect

    def logger = @logger || ActiveRecord::Base.logger

    def dialect
      return @dialect if @dialect

      name = ActiveRecord::Base.connection.adapter_name
      case name
      in "SQLite"
        :sqlite
      in "PostgreSQL" | "PostGIS"
        :postgres
      else
        "Unknown database adapter: #{name} (only SQLite and PostgreSQL are supported)."
      end
    end

    def load_rules(*filenames)
      @loaded_rules ||= {}

      # Flatten any arrays in the arguments, just for convenience.
      definition_hashes = filenames.flatten.flat_map do |filename|
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

      definitions.each do |_, (definition, _)|
        define_rule(definition)
      end

      definitions.keys
    end

    def unload_all_rules!
      @loaded_rules = {}
    end

    def define_rule(definition)
      parsed = definition.is_a?(String) ? Parse.definition(definition) : definition
      rule = Rule.new(definition: parsed)
      if (existing = @loaded_rules[rule.id]) && rule != existing
        raise <<~TEXT
          Error: hash collision between rules. Change one of the names slighly to produce different hashes.
            Existing rule: #{existing.name}
            New rule:      #{rule.name}
        TEXT
      end

      @loaded_rules[rule.id] = rule
      rule
    end

    def undefine_rule(name)
      @loaded_rules.delete_if { _2.name == name }
    end

    def after_create_trigger(record) = after_trigger(capture_create_change(record))

    def capture_create_change(record)
      [record.class.name, nil, record.attributes]
    end

    def after_update_trigger(record) = after_trigger(capture_update_change(record))

    def capture_update_change(record)
      [record.class.name,
       record.attributes.merge(record.previous_changes.transform_values(&:first)),
       record.attributes]
    end

    def after_destroy_trigger(record) = after_trigger(capture_destroy_change(record))

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

        rule = @loaded_rules[match.rule_id]
        unless rule
          logger.warn("Could not find loaded rule for match (rule id: #{match.rule_id}): ignoring match #{match.id}.")
          next
        end
        next unless rule

        rule.run_pending_execution(match)
      end
    end
    alias run_pending_execution run_pending_executions

    def activate_all
      # This might generate a *lot* of ids to process!
      @loaded_rules.flat_map do |_, rule|
        rule.activate
      end
    end

    private

    def after_trigger(change)
      activate_rules(change).each { run_pending_executions(_1) }
    end
  end
end
