# frozen_string_literal: true

require "active_record"
require "active_record_rules/definer"
require "active_record_rules/engine"
require "active_record_rules/hooks"
require "active_record_rules/jobs"
require "active_record_rules/parse"
require "active_record_rules/rule"
require "active_record_rules/rule_match"
require "active_record_rules/rule_match_id"

# A production rule system for ActiveRecord objects.
#
# Rules are defined using a eDSL which looks like this:
#
# @example Define a simple rule
#   ActiveRecordRules.define_rule("Update number of posts for user")
#     later(<<~MATCH)
#       Post(<author_id>, status = "published")
#       User(id = <author_id>)
#     MATCH
#     on_match do
#       User.find(author_id).increment!(:post_count)
#     end
#     on_unmatch do
#       User.find(author_id).decrement!(:post_count)
#     end
#   RULE
module ActiveRecordRules
  extend Definer

  class << self
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

    # Define a block to wrap around all rule executions. The block
    # will be provided with the rule that is being executed, and a
    # block to yield as the execution.
    #
    # @yieldparam [ActiveRecordRules::Rule] rule
    #   The rule being executed
    # @yieldparam [Proc] execution
    #   A Proc of the execution to be performed
    def around_execution(&block)
      if block
        @around_execution = block
      else
        @around_execution || ->(_, execution) { execution.call }
      end
    end

    # Load rules from the provided filenames by evaluating them as
    # Ruby code within the context of the ActiveRecordRules object.
    #
    # @param files [Array<String>] The filenames to load
    def load_files(filenames)
      filenames.each do |filename|
        Module.new.extend(Definer).module_eval(File.read(filename), filename)
      end
    end

    # Register a new rule with the system, to be executed when events happen.
    #
    # @param rule [Rule] The rule being registered
    def register_rule!(rule)
      @loaded_rules ||= {}
      @after_save_rules ||= {}
      @after_commit_rules ||= {}
      @after_request_rules ||= {}
      @later_rules ||= {}

      if (existing = @loaded_rules[rule.id])
        raise <<~TEXT if rule.name != existing.name
          Error: hash collision between rules. Change one of the names to produce different truncated MD5 hashes.
            Existing rule: #{existing.name}
            New rule:      #{rule.name}
        TEXT

        logger.warn("Redefining rule: #{rule.name}")
      end

      @loaded_rules[rule.id] = rule
      case rule.timing
      in :after_save
        @after_save_rules[rule.id] = rule
      in :after_commit
        @after_commit_rules[rule.id] = rule
      in :after_request
        @after_request_rules[rule.id] = rule
      in :later
        @later_rules[rule.id] = rule
      end

      # Return nothing, this is just for the mutation.
      nil
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

    # Return all rules in the system
    #
    # @return [Enumerable<Rule>] All rules in the system.
    def all_rules = @loaded_rules&.values || []

    # Deregister a rule definition by Rule object. If the provided
    # argument is not a Rule then it will be passed to find_rule to
    # find the appropriate Rule.
    #
    # @param rule [Rule, String, Integer] The rule to deregister
    # @return [nil]
    def deregister_rule!(rule)
      rule = case rule
      when String, Integer
               find_rule(rule)
      when Rule
               rule
      else
               raise "Rules can only be deregistered by name (a string), an id (an Integer), or a Rule object"
      end
      id = rule.id
      raise "Cannot find rule to undefine: #{name}" unless @loaded_rules&.delete(id)

      @after_save_rules.delete(id)
      @after_commit_rules.delete(id)
      @after_request_rules.delete(id)
      @later_rules.delete(id)
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

      [ record.class.name,
       nil,
       record.attributes.slice("id", *attrs) ]
    end

    # Capture the details of attributes in an after_update callback.
    # This will only capture attributes that are relevant to the rules
    # currently defined in the system.
    #
    # @return A change record suitable to activate rules, or nil if no activation is necessary
    def capture_update_change(record)
      attrs = [ "id", *relevant_attributes(record.class) ]
      return nil unless attrs.any? { record.previous_changes.key?(_1) }

      # Get before+after for relevant attributes
      after = record.attributes.slice(*attrs)
      before = after.merge(record.previous_changes.slice(*attrs).transform_values(&:first))

      [ record.class.name, before, after ]
    end

    # Capture the details of attributes in an after_destroy callback.
    # This will only capture attributes that are relevant to the rules
    # currently defined in the system.
    #
    # @return A change record suitable to activate rules, or nil if no activation is necessary
    def capture_destroy_change(record)
      attrs = relevant_attributes(record.class)
      return nil if attrs.empty?

      [ record.class.name,
       record.attributes.slice("id", *attrs),
       nil ]
    end

    # Activate all rules relevant to the provided change.
    #
    # @param change The change details to use to activate rules
    # @param timing [:after_save, :after_commit, :after_request, :later, :all]
    #   The timing of this activation, which filters rules that get activated
    # @return [Array<String>] The ids of RuleMatch records which need execution as a result of this activation
    def activate_rules(change, timing = :all)
      return [] if change.nil?

      rules = case timing
      in :after_save
                @after_save_rules
      in :after_commit
                @after_commit_rules
      in :after_request
                @after_request_rules
      in :later
                @later_rules
      in :all
                @loaded_rules
      end
      return [] if rules.nil?

      class_name, previous, current = change
      klass = Object.const_get(class_name)
      rules.flat_map do |_, rule|
        next [] if rule.relevant_attributes(klass).empty?

        pending = rule.calculate_required_activations(klass, previous, current)
        next [] if pending.empty?

        rule.activate(pending)
      end
    end

    # Print the output of SQL's "explain" for each rule that would be
    # activated for the provided change.
    #
    # @param change The change details to use to explain rules
    # @param output The IO object to write to
    def explain_rules(change, output = $stdout)
      class_name, previous, current = change
      klass = Object.const_get(class_name)
      @loaded_rules.each_value do |rule|
        next if rule.relevant_attributes(klass).empty?

        pending = rule.calculate_required_activations(klass, previous, current)
        next [] if pending.empty?

        output.puts(rule.explain(pending))
      end
      nil
    end

    # Schedule a "later" activation process to run. Does nothing if
    # there are no rules defined.
    #
    # @param change The change details to use to activate rules
    def schedule_later_activation(change)
      return if change.nil?
      return if @later_rules.empty?

      ActiveRecordRules::Jobs::ActivateRules.perform_later(change)
    end

    # Execute the code from rule bodies which have been matched, and
    # need to actually be run. The ids provided to this method should
    # have come from a call to ActiveRecordRules.activate_rules.
    #
    # @param ids [Array] An array of RuleMatch ids which need to be executed
    # @return nil
    def run_pending_executions(ids)
      ids_to_execute = ids
      failures = []
      total = 0
      until ids_to_execute.empty?
        executing_ids = ids_to_execute
        ids_to_execute = []
        Rule.claim_pending_executions!(executing_ids).each do |match|
          total += 1
          begin
            needs_execution = match.execute!
            ids_to_execute << match.id if needs_execution
          rescue StandardError => e
            logger.error(
              [ "Rule execution failed for match (rule id: #{match.rule_id}, match id: #{match.id}): #{e.message}",
               *e.backtrace ].join("\n")
            )
            failures << e
          end
        end
      end
      return if failures.empty?
      raise failures.first if failures.size == 1

      raise "Error running pending executions: #{failed} of #{total} failed"
    end

    def run_pending_execution(id)
      run_pending_executions([ id ])
    end

    def activate_and_execute(change, timing)
      run_pending_executions(activate_rules(change, timing))
    end

    # Evaluate all the rules relevant to a given record, running
    # "after save" and "after commit" rules immediately, and
    # scheduling "later" rules to run.
    #
    # This processes rules as if every record in the field was
    # changed, but rule bodies will only be run if there has been an
    # actual change. This may result in more *activations* than are
    # strictly necessary, but it should not cause any additional
    # *executions*.
    #
    # @param record A record to use to evaluate rules
    def evaluate_rules_for(record)
      change = if record.destroyed?
                 # if the record is marked as destroyed then we want
                 # to process it as a destroy
                 capture_destroy_change(record)
      else
                 # a "create" change is the same as changing every
                 # attribute to its current value, so will trigger
                 # anything it needs to.
                 capture_create_change(record)
      end
      ActiveRecordRules.activate_and_execute(change, :after_save)
      ActiveRecordRules.activate_and_execute(change, :after_commit)
      ActiveRecordRules.activate_and_execute(change, :after_request)
      ActiveRecordRules.schedule_later_activation(change)
      nil
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

    # Find matches which are in the "queued" state, and are waiting to
    # be executed. These will likely have an outstanding background
    # job which will execute them. If matches are stuck in a queued
    # state for a long time, this may indicate a problem with your job
    # runner.
    #
    # Matches in this list can be executed using #execute!, but this
    # will not change the queued_since value. This must be cleared
    # manually, but doing so may introduce race conditions if an
    # update to the match occurs at the same time as you are executing
    # it.
    #
    # @param limit [ActiveSupport::Duration]
    #   A timeframe beyond which a job should be reported. This is
    #   intended to find jobs which are queued and which have not run,
    #   despite a reasonable expectation that they should have been.
    def queued_matches(limit = 10.minutes)
      ActiveRecordRules::RuleMatch.where(queued_since: ..(Time.now - limit))
    end

    # Find matches which are stuck in the "running" state, and might
    # need to be executed again. It is likely that you want to run
    # #execute! on each match, but you may wish to inspect the values
    # before executing them.
    #
    # @param limit [ActiveSupport::Duration]
    #   A timeframe beyond which a job is considered "stuck" (default 10 minutes)
    def stuck_matches(limit = 10.minutes)
      ActiveRecordRules::RuleMatch.where(running_since: ..(Time.now - limit))
    end

    # Find matches which are in the "failed" state, and might need to
    # be executed again. You can inspect the values directly, and (if
    # applicable) re-run them with #execute!.
    def failed_matches
      ActiveRecordRules::RuleMatch.where.not(failed_since: nil)
    end

    # Returns all matches from the database where their rule is no
    # longer defined in the system. This is most useful to proceed
    # into a call to #delete_all, but you may wish to inspect the
    # values before deleting them.
    def defunct_matches
      ActiveRecordRules::RuleMatch.where.not(rule_id: @loaded_rules.keys)
    end

    # Run the provided block, activating and executing any pending
    # "after request" rules from within.
    #
    # This is intended to be registered in a Rack middleware or a
    # Rails "around action" callback.
    def wrap_request(&block)
      old = Thread.current[:pending_active_record_rules_changes]
      Thread.current[:pending_active_record_rules_changes] = []

      block.call
    ensure
      Thread.current[:pending_active_record_rules_changes].each do |change|
        ActiveRecordRules.activate_and_execute(change, :after_request)
      end

      Thread.current[:pending_active_record_rules_changes] = old
    end

    private

    def relevant_attributes(klass)
      all_rules.map do |rule|
        rule.relevant_attributes(klass)
      end.compact.reduce(Set.new, &:+)
    end
  end
end
