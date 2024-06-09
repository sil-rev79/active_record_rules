# frozen_string_literal: true

require "digest/md5"

module ActiveRecordRules
  class Rule
    attr_reader :id, :name, :definition

    def initialize(definition:)
      @name = definition.name
      @definition = definition
      @id, = Rule.name_to_id(definition.name)
    end

    def timing = definition.timing

    # The id is the MD5 hash of the definition's name, truncated to a
    # 32 bit integer, in network (big) endian byte order. These
    # objects should be part of the source of a program, so we're not
    # concerned with malicious collisions - a developer can resolve a
    # collision by manually changing a rule definition.
    def self.name_to_id(name)
      Digest::MD5.digest(name).unpack1("l>")
    end

    def rule_matches = RuleMatch.where(id: id)

    def ==(other)
      super || definition.unparse == other.definition.unparse
    end

    def self.claim_pending_executions!(ids, timing)
      return RuleMatch.find(ids) unless timing == :async

      quoted_ids = ids.map { ActiveRecord::Base.connection.quote(_1) }
      attributes = ActiveRecord::Base.connection.execute(<<~SQL.squish!)
        update #{RuleMatch.table_name}
           set running_since = current_timestamp,
               queued_since = null
          where id in (#{quoted_ids.join(", ")})
            and (queued_since is not null or failed_since is not null)
            and running_since is null
          returning id
      SQL

      # If we don't find attributes, then we haven't claimed anything,
      # so return nil.
      return [] if attributes.empty?

      # This hits the database again, which I don't love, but it's
      # tricky to construct a new ActiveRecord object that thinks it's
      # persisted without doing this.
      RuleMatch.find(attributes.pluck("id"))
    end

    def run_pending_execution(match)
      raise "Cannot run execution meant for another rule!" unless match.rule_id == id

      case match
      in RuleMatch(live_arguments: nil, next_arguments: nil)
        match.delete

      in RuleMatch(ids:, live_arguments:, next_arguments: nil)
        logger&.info { "Rule(#{id}): unmatched for #{ids.to_json}" }
        logger&.debug { "Rule(#{id}): unmatched with arguments #{live_arguments.to_json}" }

        begin
          execute_unmatch(live_arguments)
        rescue StandardError => e
          ActiveRecord::Base.connection.execute(<<~SQL.squish!)
            update #{RuleMatch.table_name}
               set failed_since = current_timestamp
             where id = #{ActiveRecord::Base.connection.quote(match.id)}
          SQL
          raise e
        end

        match.delete

      in RuleMatch(ids:, live_arguments: nil, next_arguments:)
        logger&.info { "Rule(#{id}): matched for #{ids.to_json}" }
        logger&.debug { "Rule(#{id}): matched with arguments #{next_arguments.to_json}" }

        begin
          execute_match(next_arguments)
        rescue StandardError => e
          ActiveRecord::Base.connection.execute(<<~SQL.squish!)
            update #{RuleMatch.table_name}
               set running_since = null,
                   failed_since = current_timestamp
             where id = #{ActiveRecord::Base.connection.quote(match.id)}
          SQL
          raise e
        end

        ActiveRecord::Base.connection.execute(<<~SQL.squish!)
          update #{RuleMatch.table_name}
             set running_since = null,
                 failed_since = null,
                 live_arguments = #{ActiveRecord::Base.connection.quote(next_arguments.to_json)},
                 next_arguments = case when next_arguments = #{ActiveRecord::Base.connection.quote(next_arguments.to_json)} then
                                    null
                                  else
                                    next_arguments
                                  end
           where id = #{ActiveRecord::Base.connection.quote(match.id)}
        SQL

      in RuleMatch(ids:, live_arguments:, next_arguments:)
        logger&.info { "Rule(#{id}): updated for #{ids.to_json}" }
        logger&.debug do
          "Rule(#{id}): updating from #{live_arguments.to_json} " \
            "=> #{next_arguments.to_json}"
        end

        begin
          execute_update(live_arguments, next_arguments)
        rescue StandardError => e
          ActiveRecord::Base.connection.execute(<<~SQL.squish!)
            update #{RuleMatch.table_name}
               set running_since = null,
                   failed_since = current_timestamp
             where id = #{ActiveRecord::Base.connection.quote(match.id)}
          SQL
          raise e
        end

        ActiveRecord::Base.connection.execute(<<~SQL.squish!)
          update #{RuleMatch.table_name}
             set running_since = null,
                 live_arguments = #{ActiveRecord::Base.connection.quote(next_arguments.to_json)},
                 next_arguments = case when next_arguments = #{ActiveRecord::Base.connection.quote(next_arguments.to_json)} then
                                    null
                                  else
                                    next_arguments
                                  end
           where id = #{ActiveRecord::Base.connection.quote(match.id)}
        SQL
      end
    end

    def calculate_required_activations(klass, previous, current)
      definition.affected_ids_sql(klass, previous, current)
    end

    def relevant_attributes_by_class
      definition.relevant_attributes_by_class
    end

    def activate(pending_activations = nil)
      plain_sql_conditions = format_plain_sql_conditions(pending_activations)
      json_sql_conditions = format_json_sql_conditions(pending_activations)

      if plain_sql_conditions == "false"
        logger&.info { "Rule(#{id}): activating rule with no pending activations - doing nothing" }
        return []
      elsif plain_sql_conditions == "true"
        logger&.info { "Rule(#{id}): activating rule for all records" }
      else
        logger&.info { "Rule(#{id}): activating rule" }
        logger&.debug do
          "Rule(#{id}): activating for: \n  " + pending_activations.map do |pending_activation|
            format_plain_sql_conditions([pending_activation])
          end.join("\n  ")
        end
      end

      ActiveRecord::Base.connection.execute(<<~SQL.squish!).map { _1["id"] }
        insert into #{RuleMatch.table_name}(rule_id, ids, queued_since, next_arguments)
          select #{ActiveRecord::Base.connection.quote(id)},
                 coalesce(record.ids, match.ids),
                 case when record.arguments = match.live_arguments then
                   match.queued_since
                 else
                   coalesce(match.queued_since, current_timestamp)
                 end,
                 case when record.arguments = match.live_arguments then
                   match.next_arguments
                 else
                   record.arguments
                 end
            from (
              #{definition.to_query_sql.split("\n").join("\n      ")}
               where (#{plain_sql_conditions})
            ) as record
            full outer join (
              select queued_since,
                     ids,
                     live_arguments,
                     next_arguments
                from #{RuleMatch.table_name}
               where rule_id = #{ActiveRecord::Base.connection.quote(id)}
                 and (#{json_sql_conditions})
            ) as match on match.ids = record.ids
           where true
          on conflict(rule_id, ids) do update
            set queued_since = excluded.queued_since,
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
