# frozen_string_literal: true

require "digest/md5"

module ActiveRecordRules
  class Rule
    attr_reader :id, :name, :definition

    def initialize(definition:)
      @name = definition.name
      @definition = definition
      # The id is the MD5 hash, truncated to a 32 bit integer, in
      # network (big) endian byte order. These objects should be part
      # of the source of a program, so we're not concerned with
      # malicious collisions - a developer can resolve a collision
      # by manually changing a rule definition.
      @id, = Digest::MD5.digest([definition.name, definition.constraints.map(&:unparse)].join("\n")).unpack("l>")
    end

    def rule_matches = RuleMatch.where(id: id)

    def ==(other)
      super || definition.unparse == other.definition.unparse
    end

    def run_pending_execution(match)
      raise "Cannot run execution meant for another rule!" unless match.rule_id == id

      case match
      in RuleMatch(awaiting_execution: "match", ids:, next_arguments:)
        match.update_columns(live_arguments: next_arguments,
                             next_arguments: nil,
                             awaiting_execution: "none")
        logger&.info { "Rule(#{id}): matched for #{ids.to_json}" }
        logger&.debug { "Rule(#{id}): matched with arguments #{next_arguments.to_json}" }

        execute_match(next_arguments)

      in RuleMatch(awaiting_execution: "update", ids:, live_arguments:, next_arguments:)
        match.update_columns(live_arguments: next_arguments,
                             next_arguments: nil,
                             awaiting_execution: "none")
        logger&.info { "Rule(#{id}): updated for #{ids.to_json}" }
        logger&.debug do
          "Rule(#{id}): updating from #{live_arguments.to_json} " \
            "=> #{next_arguments.to_json}"
        end

        execute_update(live_arguments, next_arguments)

      in RuleMatch(awaiting_execution: "unmatch", ids:, live_arguments:)
        match.delete
        logger&.info { "Rule(#{id}): unmatched for #{ids.to_json}" }
        logger&.debug { "Rule(#{id}): unmatched with arguments #{live_arguments.to_json}" }

        execute_unmatch(live_arguments)

      in RuleMatch(awaiting_execution: "delete")
        match.delete

      in RuleMatch(awaiting_execution: "none")
        # do nothing

      end
    end

    def ignore_pending_executions
      rule_matches.where(awaiting_execution: ["unmatch", "delete"]).delete_all
      rule_matches.where(awaiting_execution: ["match", "update"]).update_all(<<~SQL.squish!)
        live_arguments = next_arguments,
        next_arguments = null,
        awaiting_execution = #{RuleMatch.awaiting_executions["none"]}
      SQL
    end

    def calculate_required_activations(klass, previous, current)
      definition.affected_ids_sql(klass, previous, current)
    end

    def activate(pending_activations = nil)
      ActiveRecord::Base.connection.execute(<<~SQL.squish!).map { _1["id"] }
        insert into arr__rule_matches(rule_id, ids, awaiting_execution, live_arguments, next_arguments)
          select #{ActiveRecord::Base.connection.quote(id)},
                 coalesce(record.ids, match.ids),
                 case
                   when record.ids is null and match.awaiting_execution = #{RuleMatch.awaiting_executions["match"]}
                     then #{RuleMatch.awaiting_executions["delete"]}
                   when record.ids is null
                     then #{RuleMatch.awaiting_executions["unmatch"]}
                   when match.ids is null or match.awaiting_execution = #{RuleMatch.awaiting_executions["match"]}
                     then #{RuleMatch.awaiting_executions["match"]}
                   when record.arguments = match.live_arguments
                     then match.awaiting_execution
                   else
                     #{RuleMatch.awaiting_executions["update"]}
                 end,
                 match.live_arguments,
                 case when record.arguments = match.live_arguments then
                   match.next_arguments
                 else
                   coalesce(record.arguments, match.next_arguments)
                 end
            from (
              #{definition.to_query_sql.split("\n").join("\n      ")}
               where (#{format_plain_sql_conditions(pending_activations)})
            ) as record
            full outer join (
              select ids,
                     awaiting_execution,
                     live_arguments,
                     next_arguments
                from #{RuleMatch.table_name}
               where rule_id = #{ActiveRecord::Base.connection.quote(id)}
                 and (#{format_json_sql_conditions(pending_activations)})
            ) as match on match.ids = record.ids
           where true
          on conflict(rule_id, ids) do update
            set awaiting_execution = excluded.awaiting_execution,
                live_arguments = excluded.live_arguments,
                next_arguments = excluded.next_arguments
          returning id
      SQL
    end

    PendingActivation = Struct.new(:condition_terms, :condition_sql)

    private

    def format_plain_sql_conditions(pending_activations)
      return "true" if pending_activations.nil? || pending_activations.include?(:all)
      return "false" if pending_activations.empty?

      pending_activations.map do |pending_activation|
        ids = pending_activation.condition_terms.map { "q.__id_#{_1}" }
        "(#{ids.join(", ")}) in (#{pending_activation.condition_sql})"
      end.join(" or ")
    end

    def format_json_sql_conditions(pending_activations)
      return "true" if pending_activations.nil? || pending_activations.include?(:all)
      return "false" if pending_activations.empty?

      pending_activations.map do |pending_activation|
        case ActiveRecordRules.dialect
        in :sqlite
          terms = pending_activation.condition_terms.map { "ids->>'#{_1}'" }
          "(#{terms.join(", ")}) in (#{pending_activation.condition_sql})"
        in :postgres
          terms = pending_activation.condition_terms.flat_map { ["'#{_1}'", "_ids.#{_1}"] }
          <<~SQL
            ids @> any(
              (select jsonb_build_object(#{terms.join(", ")}) from (#{pending_activation.condition_sql}) as _ids)
            )
          SQL
        end
      end.join(" or ")
    end

    def logger
      ActiveRecordRules.logger
    end

    def argument_binding_parts(args_name)
      @argument_binding_parts ||=
        definition.bound_names.map { "#{_1} = #{args_name}[\"#{_1}\"]" }
    end

    def on_match_proc
      @on_match_proc ||= Object.new.instance_eval(<<~RUBY, __FILE__, __LINE__ + 1)
        # ->(__arguments) {
        #   a = __arguments["a"]
        #   code to run when matching
        # }
        ->(__arguments) {
          #{argument_binding_parts("__arguments").join("\n  ")}
          #{definition.on_match}
        }
      RUBY
    end

    def on_unmatch_proc
      @on_unmatch_proc ||= Object.new.instance_eval(<<~RUBY, __FILE__, __LINE__ + 1)
        # ->(__arguments) {
        #   a = __arguments["a"]
        #   code to run when matching
        # }
        ->(__arguments) {
          #{argument_binding_parts("__arguments").join("\n  ")}
          #{definition.on_unmatch}
        }
      RUBY
    end

    def on_update_proc
      return unless definition.on_update

      @on_update_proc ||= Object.new.instance_eval(<<~RUBY, __FILE__, __LINE__ + 1)
        # ->(__arguments) {
        #   a = __arguments["a"]
        #   code to run when updating
        # }
        ->(__arguments) {
          #{argument_binding_parts("__arguments").join("\n  ")}
          #{definition.on_update}
        }
      RUBY
    end

    def execute_match(args)
      context.instance_exec(args, &on_match_proc)
    end

    ArgumentPair = Struct.new(:old, :new)

    def execute_update(old_args, new_args)
      if on_update_proc
        arg_pairs = (old_args.keys.to_set + new_args.keys.to_set).to_h do |key|
          [key, ArgumentPair.new(old_args[key], new_args[key])]
        end
        context.instance_exec(arg_pairs, &on_update_proc)
      else
        context.instance_exec(old_args, &on_unmatch_proc)
        context.instance_exec(new_args, &on_match_proc)
      end
    end

    def execute_unmatch(args)
      context.instance_exec(args, &on_unmatch_proc)
    end

    def context
      if ActiveRecordRules.execution_context.nil?
        Object.new
      elsif ActiveRecordRules.execution_context.is_a?(Proc)
        ActiveRecordRules.execution_context.call
      else
        ActiveRecordRules.execution_context
      end
    end
  end
end
