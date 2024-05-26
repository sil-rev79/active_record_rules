# frozen_string_literal: true

require "active_record"
require "active_record_rules/parse"
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
module ActiveRecordRules
  cattr_accessor :execution_context

  class << self
    attr_accessor :execution_context
    attr_writer :logger, :dialect

    # Get the current logger. Defaults to ActiveRecord::Base.logger if
    # no logger is set.
    def logger = @logger || ActiveRecord::Base.logger

    # Get the current SQL dialect to use. Defaults based on the
    # ActiveRecord adapter for the current connection.
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

    # Load rules from a set of files. The rules will be checked for
    # duplicates before being loaded into the system.
    #
    # The provided filenames will be flattened prior to loading.
    #
    # @param filenames [Array<String>] The files to load rules from
    # @return [Array<Rule>] The rules that were just defined
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

      definitions.map do |_, (definition, _)|
        define_rule(definition)
      end
    end

    # Remove all rules from the in-memory database. This is unlikely
    # to be what you want.
    def unload_all_rules!
      @loaded_rules = {}
    end

    # Define a new rule by providing a definition, either as a string
    # or as a parsed Definition object.
    #
    # @param definition [String, Definition] The definition of the rule
    # @return [Rule] The newly defined Rule object.
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

    # Retrieve a Rule by name
    #
    # @param name [String] The rule name to find
    # @return [Rule, nil] The rule, or nil if that rule is not defined
    def find_rule(name)
      @loaded_rules[Rule.name_to_id(name)]
    end

    # Remove a Rule definition by name
    #
    # @param name [String] The rule name to remove
    # @return [nil]
    def undefine_rule(name)
      @loaded_rules.delete_if { _2.name == name }
      nil
    end

    # Process a change in an after_create callback. This captures the
    # attributes of the object, then activates any relevant rules and
    # executes the matches.
    def after_create_trigger(record) = after_trigger(capture_create_change(record))

    # Capture the details of attributes in an after_create callback.
    # This will only capture attributes that are relevant to the rules
    # currently defined in the system.
    #
    # @return A change record suitable to activate rules, or nil if no activation is necessary
    def capture_create_change(record)
      attrs = relevant_attributes(record.class)
      return nil if attrs.empty?

      [record.class.name,
       nil,
       record.attributes.slice("id", *attrs)]
    end

    # Process a change in an after_update callback. This captures the
    # attributes of the object, then activates any relevant rules and
    # executes the matches.
    def after_update_trigger(record) = after_trigger(capture_update_change(record))

    # Capture the details of attributes in an after_update callback.
    # This will only capture attributes that are relevant to the rules
    # currently defined in the system.
    #
    # @return A change record suitable to activate rules, or nil if no activation is necessary
    def capture_update_change(record)
      attrs = relevant_attributes(record.class)
      return nil if attrs.empty?

      # Get before+after for relevant attributes, then bail out if
      # there's no change in them.
      after = record.attributes.slice("id", *attrs)
      before = after.merge(record.previous_changes.slice("id", *attrs).transform_values(&:first))
      return nil if before == after

      [record.class.name, before, after]
    end

    # Process a change in an after_destroy callback. This captures the
    # attributes of the object, then activates any relevant rules and
    # executes the matches.
    def after_destroy_trigger(record) = after_trigger(capture_destroy_change(record))

    # Capture the details of attributes in an after_destroy callback.
    # This will only capture attributes that are relevant to the rules
    # currently defined in the system.
    #
    # @return A change record suitable to activate rules, or nil if no activation is necessary
    def capture_destroy_change(record)
      attrs = relevant_attributes(record.class)
      return nil if attrs.empty?

      [record.class.name,
       record.attributes.slice("id", *attrs),
       nil]
    end

    # Activate all rules relevant to the provided change.
    #
    # @param change The change details to use to activate rules
    # @return [Array<String>] The ids of RuleMatch records which need execution as a result of this activation
    def activate_rules(change)
      return [] if change.nil?

      class_name, previous, current = change
      klass = Object.const_get(class_name)
      @loaded_rules.flat_map do |_, rule|
        next [] if rule.relevant_attributes_by_class[klass].nil?

        pending = rule.calculate_required_activations(klass, previous, current)
        next [] if pending.empty?

        rule.activate(pending)
      end
    end

    # Execute the code from rule bodies which have been matched, and
    # need to actually be run. The ids provided to this method should
    # have come from a call to ActiveRecordRules.activate_rules.
    #
    # @param ids [Array] An array of RuleMatch ids which need to be executed
    # @return nil
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
      nil
    end
    alias run_pending_execution run_pending_executions

    # Activate all rules, for all records. This may generate a *lot*
    # of ids to process. These ids should then be passed into the
    # ActiveRecordRules.run_pending_executions method.
    #
    # @return [Array<String>] The ids of RuleMatch records which need execution as a result of this activation
    def activate_all
      # This might generate a *lot* of ids to process!
      @loaded_rules.flat_map do |_, rule|
        rule.activate
      end
    end

    private

    def relevant_attributes(klass)
      @loaded_rules.map do |_, rule|
        rule.relevant_attributes_by_class[klass] || Set.new
      end.reduce(Set.new, &:+)
    end

    def after_trigger(change)
      activate_rules(change).each { run_pending_executions(_1) }
    end
  end
end
