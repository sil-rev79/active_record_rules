# frozen_string_literal: true

module ActiveRecordRules
  class Rule < ActiveRecord::Base
    self.table_name = :arr__rules

    has_many :rule_matches, dependent: :destroy

    def run_pending_executions
      rule_matches.delete_by(awaiting_execution: "delete")

      rule_matches.where(awaiting_execution: "unmatch").in_batches do |batch|
        all_rows = batch.pluck(:ids, :live_arguments)

        # Go through each record and run the unmatch code
        all_rows.map do |ids, live_arguments|
          logger&.info { "Rule(#{id}): unmatched for #{ids.to_json}" }
          logger&.debug { "Rule(#{id}): unmatched with arguments #{live_arguments.to_json}" }

          execute_unmatch(live_arguments)
        end

        # Then remove them
        batch.delete_all
      end

      rule_matches.where(awaiting_execution: "update").in_batches do |batch|
        all_rows = batch.pluck(:ids, :live_arguments, :next_arguments)

        # Go through each record and run the update code
        all_rows.map do |ids, live_arguments, next_arguments|
          logger&.info { "Rule(#{id}): updated for #{ids.to_json}" }
          logger&.debug do
            "Rule(#{id}): updating from #{live_arguments.to_json} " \
              "=> #{next_arguments.to_json}"
          end

          execute_update(live_arguments, next_arguments)
        end

        # Then mark them as being done
        batch.update_all(<<~SQL.squish)
          live_arguments = next_arguments,
          next_arguments = null,
          awaiting_execution = #{RuleMatch.awaiting_executions["none"]}
        SQL
      end

      rule_matches.where(awaiting_execution: "match").in_batches do |batch|
        all_ids = batch.pluck(:ids, :next_arguments)

        # Go through each record and run the match code
        all_ids.map do |ids, next_arguments|
          logger&.info { "Rule(#{id}): matched for #{ids.to_json}" }
          logger&.debug { "Rule(#{id}): matched with arguments #{next_arguments.to_json}" }

          execute_match(next_arguments)
        end

        # Then mark them as being done
        batch.update_all(<<~SQL.squish)
          live_arguments = next_arguments,
          next_arguments = null,
          awaiting_execution = #{RuleMatch.awaiting_executions["none"]}
        SQL
      end
    end

    def ignore_pending_executions
      rule_matches.where(awaiting_execution: ["unmatch", "delete"]).delete_all
      rule_matches.where(awaiting_execution: ["match", "update"]).update_all(<<~SQL.squish)
        live_arguments = next_arguments,
        next_arguments = null,
        awaiting_execution = #{RuleMatch.awaiting_executions["none"]}
      SQL
    end

    def activate(_keys_to_ids = nil)
      # pp(name)
      # puts(parsed_definition.to_query_sql)
      # pp(ActiveRecord::Base.connection.select_all(<<~SQL).rows)
      #   select #{ActiveRecord::Base.connection.quote(id)},
      #          coalesce(record.ids, match.ids),
      #          case
      #            when record.ids is null and match.awaiting_execution = #{RuleMatch.awaiting_executions["match"]}
      #              then #{RuleMatch.awaiting_executions["delete"]}
      #            when record.ids is null
      #              then #{RuleMatch.awaiting_executions["unmatch"]}
      #            when match.ids is null or match.awaiting_execution = #{RuleMatch.awaiting_executions["match"]}
      #              then #{RuleMatch.awaiting_executions["match"]}
      #            else
      #              #{RuleMatch.awaiting_executions["update"]}
      #          end,
      #          match.live_arguments,
      #          coalesce(record.arguments, match.next_arguments)
      #     from (
      #       #{parsed_definition.to_query_sql.split("\n").join("\n    ")}
      #     ) as record
      #     full outer join (
      #       select ids,
      #              awaiting_execution,
      #              live_arguments,
      #              next_arguments
      #         from #{RuleMatch.table_name}
      #        where rule_id = #{ActiveRecord::Base.connection.quote(id)}
      #     ) as match on match.ids = record.ids
      # SQL

      ActiveRecord::Base.connection.execute(<<~SQL.squish)
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
              #{parsed_definition.to_query_sql.split("\n").join("\n      ")}
            ) as record
            full outer join (
              select ids,
                     awaiting_execution,
                     live_arguments,
                     next_arguments
                from #{RuleMatch.table_name}
               where rule_id = #{ActiveRecord::Base.connection.quote(id)}
            ) as match on match.ids = record.ids
           where true
          on conflict(rule_id, ids) do update
            set awaiting_execution = excluded.awaiting_execution,
                live_arguments = excluded.live_arguments,
                next_arguments = excluded.next_arguments
      SQL

      # pp(:after, rule_matches.reload.to_a)
    end

    private

    def parsed_definition
      @parsed_definition ||= ActiveRecordRules::Parse.definition(definition)
    end

    def logger
      ActiveRecordRules.logger
    end

    def argument_binding_parts(args_name)
      @argument_binding_parts ||=
        parsed_definition.bound_names.map { "#{_1} = #{args_name}[\"#{_1}\"]" }
    end

    def on_match_proc
      @on_match_proc ||= Object.new.instance_eval(<<~RUBY, __FILE__, __LINE__ + 1)
        # ->(__arguments) {
        #   a = __arguments["a"]
        #   code to run when matching
        # }
        ->(__arguments) {
          #{argument_binding_parts("__arguments").join("\n  ")}
          #{parsed_definition.on_match}
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
          #{parsed_definition.on_unmatch}
        }
      RUBY
    end

    def on_update_proc
      return unless parsed_definition.on_update

      @on_update_proc ||= Object.new.instance_eval(<<~RUBY, __FILE__, __LINE__ + 1)
        # ->(__arguments) {
        #   a = __arguments["a"]
        #   code to run when updating
        # }
        ->(__arguments) {
          #{argument_binding_parts("__arguments").join("\n  ")}
          #{parsed_definition.on_update}
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
