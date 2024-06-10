# frozen_string_literal: true

require "active_record"
require "active_record_rules/hooks"
require "active_record_rules/jobs"
require "active_record_rules/parse"
require "active_record_rules/rule"
require "active_record_rules/rule_match"

# A production rule system for ActiveRecord objects.
#
# Rules are defined using a DSL which looks like this:
#
# @example Define a simple rule#
#   ActiveRecordRules.define_rule(<<~RULE)
#     async rule: Update number of posts for user
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
          lloc = "#{lfilename}:#{l.location[0]}"
          rloc = "#{rfilename}:#{r.location[0]}"
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
      @after_save_rules = {}
      @after_commit_rules = {}
      @async_rules = {}
    end

    # Define a new rule by providing a definition, either as a string
    # or as a parsed Definition object.
    #
    # @param definition [String, Definition] The definition of the rule
    # @return [Rule] The newly defined Rule object.
    def define_rule(definition)
      @loaded_rules ||= {}
      @after_save_rules ||= {}
      @after_commit_rules ||= {}
      @async_rules ||= {}

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
      case rule.timing
      in :after_save
        @after_save_rules[rule.id] = rule
      in :after_commit
        @after_commit_rules[rule.id] = rule
      in :async
        @async_rules[rule.id] = rule
      end
      rule
    end

    # Retrieve a Rule by name
    #
    # @param name_or_id [String, Integer] The rule name or id to find
    # @return [Rule, nil] The rule, or nil if that rule is not defined
    def find_rule(name_or_id)
      return nil if @loaded_rules.nil?

      case name_or_id
      when String
        @loaded_rules[Rule.name_to_id(name_or_id)]
      when Integer
        @loaded_rules[name_or_id]
      else
        raise "Rules can only be found by name (a String) or id (an Integer)."
      end
    end

    # Remove a Rule definition by name
    #
    # @param name [String] The rule name to remove
    # @return [nil]
    def undefine_rule(name)
      id = Rule.name_to_id(name)
      raise "Cannot find rule to undefine: #{name}" unless @loaded_rules&.delete(id)

      @after_save_rules.delete(id)
      @after_commit_rules.delete(id)
      @async_rules.delete(id)
      nil
    end

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

    # Capture the details of attributes in an after_update callback.
    # This will only capture attributes that are relevant to the rules
    # currently defined in the system.
    #
    # @return A change record suitable to activate rules, or nil if no activation is necessary
    def capture_update_change(record)
      attrs = ["id", *relevant_attributes(record.class)]
      return nil unless attrs.any? { record.previous_changes.key?(_1) }

      # Get before+after for relevant attributes
      after = record.attributes.slice(*attrs)
      before = after.merge(record.previous_changes.slice(*attrs).transform_values(&:first))

      [record.class.name, before, after]
    end

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
    # @param timing [:after_save, :after_commit, :async, :all]
    #   The timing of this activation, which filters rules that get activated
    # @return [Array<String>] The ids of RuleMatch records which need execution as a result of this activation
    def activate_rules(change, timing = :all)
      return [] if change.nil?

      rules = case timing
              in :after_save
                @after_save_rules
              in :after_commit
                @after_commit_rules
              in :async
                @async_rules
              in :all
                @loaded_rules
              end
      return [] if rules.nil?

      class_name, previous, current = change
      klass = Object.const_get(class_name)
      rules.flat_map do |_, rule|
        next [] if rule.relevant_attributes_by_class[klass].nil?

        pending = rule.calculate_required_activations(klass, previous, current)
        next [] if pending.empty?

        rule.activate(pending)
      end
    end

    # Schedule an Async activation process to run. Does nothing if
    # there are no rules defined.
    #
    # @param change The change details to use to activate rules
    def schedule_async_activation(change)
      return if change.nil?
      return if @async_rules.empty?

      ActiveRecordRules::Jobs::ActivateRules.perform_later(change)
    end

    # Execute the code from rule bodies which have been matched, and
    # need to actually be run. The ids provided to this method should
    # have come from a call to ActiveRecordRules.activate_rules.
    #
    # @param ids [Array] An array of RuleMatch ids which need to be executed
    # @return nil
    def run_pending_executions(ids, timing = :all)
      Rule.claim_pending_executions!(ids, timing).each do |match_id, rule_id|
        rule = @loaded_rules[rule_id]
        unless rule
          logger.warn("Could not find loaded rule for match (rule id: #{rule_id}): ignoring match #{match_id}.")
          next
        end
        next unless rule

        rule.run_pending_execution(match_id)
      end
      nil
    end

    def run_pending_execution(id, timing = :all)
      run_pending_executions([id], timing)
    end

    def activate_and_execute(change, timing = :all)
      run_pending_executions(activate_rules(change, timing), timing)
    end

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
  end
end
