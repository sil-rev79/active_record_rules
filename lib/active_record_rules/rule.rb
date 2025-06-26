# frozen_string_literal: true

require "digest/md5"

module ActiveRecordRules
  class Rule
    attr_reader :id, :name, :timing, :constraints, :on_match, :on_update, :on_unmatch, :context, :source_location

    def initialize(name:, timing:, constraints:, on_match:, on_update:, on_unmatch:, context:, source_location:)
      @name = name
      @timing = timing
      @constraints = constraints
      @on_match = on_match
      @on_update = on_update
      @on_unmatch = on_unmatch
      @context = context
      context_class = ExecutionContext.for_variables(constraints.bound_names)
      @context_builder = case @context
                         when Proc
                           ->(args) { context_class.new(@context.call, args) }
                         else
                           ->(args) { context_class.new(@context, args) }
                         end
      @source_location = source_location

      @id = Rule.name_to_id(@name)

      # This is a lazily populated cache of details per-class.
      # TODO: construct this up-front
      @attributes_by_class = {}

      freeze # We want these to be immutable, so we'll at least freeze the top-level
    end

    # The id is the MD5 hash of the definition's name, truncated to a
    # 32 bit integer, in network (big) endian byte order. These
    # objects should be part of the source of a program, so we're not
    # concerned with malicious collisions - a developer can resolve a
    # collision by manually changing a rule definition.
    def self.name_to_id(name)
      Digest::MD5.digest(name).unpack1("l>")
    end

    def rule_matches = RuleMatch.where(rule_id: id)

    def rule_matches_for(record)
      queries = calculate_required_activations(record.class, nil, record.attributes).map do |condition|
        clauses = condition.condition_terms.map do |term|
          "(match_id.record_id = __ids.#{term} and match_id.name = #{ActiveRecord::Base.connection.quote(term)})"
        end

        <<~SQL
          (with __ids as (#{condition.condition_sql})
           select distinct match.* from #{RuleMatch.table_name} match
             cross join __ids
             join #{RuleMatchId.table_name} match_id on match.id = match_id.rule_match_id
            where #{clauses.join(" or ")})
        SQL
      end

      if queries.empty?
        RuleMatch.none
      else
        RuleMatch.from("(#{queries.join(" UNION ")}) as #{RuleMatch.table_name}")
      end
    end

    def ==(other)
      super || constraints.unparse == other.constraints.unparse
    end

    def inspect
      "#<#{self.class.name} id=#{id} name=#{name} (#{@source_location.join(":")})>"
    end

    def to_s = inspect

    def self.claim_pending_executions!(ids)
      return [] if ids.empty?

      quoted_ids = ids.map { ActiveRecord::Base.connection.quote(_1) }
      RuleMatch.find_by_sql(<<~SQL.squish!)
        update #{RuleMatch.table_name}
           set running_since = current_timestamp,
               queued_since = null
          where id in (#{quoted_ids.join(", ")})
            and (queued_since is not null or failed_since is not null)
            and running_since is null
          returning *
      SQL
    end

    def calculate_required_activations(klass, previous, current)
      constraints.affected_ids_sql(klass, previous, current)
    end

    def relevant_attributes(klass)
      @attributes_by_class[klass] ||=
        constraints.relevant_attributes_by_class.map do |klass_key, attributes|
          klass <= klass_key ? attributes : Set.new
        end.reduce(Set.new, &:+)

      @attributes_by_class[klass]
    end

    def activate(pending_activations = nil)
      result = build_queries(pending_activations, logger).flat_map do |query|
        ActiveRecord::Base.connection.execute(query).to_a.pluck("id")
      end.uniq
      fixup_missing_ids!

      result
    end

    def explain(pending_activations = nil)
      build_queries(pending_activations, nil).map do |query|
        ActiveRecord::Base.connection.execute("explain #{query}").to_a.map { _1.values.first }
      end
    end

    PendingActivation = Struct.new(:condition_terms, :condition_sql)

    ArgumentPair = Struct.new(:old, :new)

    def execute_match(args)
      wrap_execution { @context_builder.call(args).instance_exec(&@on_match) } if @on_match
    end

    def execute_update(old_args, new_args)
      if @on_update
        arg_pairs = (old_args.keys.to_set + new_args.keys.to_set).to_h do |key|
          [key, ArgumentPair.new(old_args[key], new_args[key])]
        end
        wrap_execution do
          @context_builder.call(arg_pairs).instance_exec(&@on_update)
        end
      else
        execute_unmatch(old_args)
        execute_match(new_args)
      end
    end

    def execute_unmatch(args)
      wrap_execution { @context_builder.call(args).instance_exec(&@on_unmatch) } if @on_unmatch
    end

    private

    def wrap_execution(&block)
      count = 0
      execution = lambda do
        count += 1
        block.call
      end
      ActiveRecordRules.around_execution.call(self, execution)
      return if count == 1

      location = ActiveRecordRules.around_execution.source_location.join(":")
      raise "Execution context did not execute rule body for rule #{id} (context at #{location})" if count.zero?

      raise "Execution context executed rule body #{count} times for rule #{id} (context at #{location})"
    end

    # Add records to the "ids" join table where needed
    def fixup_missing_ids!
      missing_ids = ActiveRecord::Base.connection.execute(<<~SQL.squish!).pluck("id")
        update #{RuleMatch.table_name}
           set missing_ids = false
         where missing_ids
         returning id
      SQL

      return if missing_ids.empty?

      json_each, id_cast = case ActiveRecordRules.dialect
                           in :sqlite
                             ["json_each",
                              ""]
                           in :postgres
                             ["jsonb_each_text",
                              ":: #{RuleMatchId.attribute_types["record_id"]&.type}"]
                           end

      quoted_ids = missing_ids.map { ActiveRecord::Base.connection.quote(_1) }

      ActiveRecord::Base.connection.execute(<<~SQL.squish!)
        insert into #{RuleMatchId.table_name}(rule_id, rule_match_id, name, record_id)
          select rule_id, #{RuleMatch.table_name}.id, ref.key, ref.value#{id_cast}
            from #{RuleMatch.table_name}, #{json_each}(ids) as ref
           where #{RuleMatch.table_name}.id in (#{quoted_ids.join(",")})
      SQL
    end

    def build_queries(pending_activations, logger)
      conditions = format_sql_conditions(pending_activations)

      if conditions == false
        logger&.info { "Rule(#{id}): activating rule with no pending activations - doing nothing" }
        return []
      end

      if conditions == true
        logger&.info { "Rule(#{id}): activating rule for all records" }
        # We need a valid SQL query here, and "select 1" is about as
        # trivial as I can think of. The conditions being "true" means
        # that we won't actually use the result of the query, so it
        # should be fine.
        conditions = [["select 1", "true", "true"]]
      else
        logger&.info { "Rule(#{id}): activating rule" }
        logger&.debug do
          "Rule(#{id}): activating for: \n  " + pending_activations.flat_map do |pending_activation|
            format_sql_conditions([pending_activation]).map(&:first)
          end.join("\n  ")
        end
      end

      conditions.map do |sql, plain_sql, json_sql|
        <<~SQL.squish!
          with __ids as (#{sql})
            insert into #{RuleMatch.table_name}(rule_id, ids, queued_since, next_arguments)
              select #{ActiveRecord::Base.connection.quote(id)},
                     coalesce(record.ids, match.ids),
                     coalesce(match.queued_since, current_timestamp),
                     record.arguments
                from (
                  #{constraints.to_query_sql.split("\n").join("\n      ")}
                   where #{plain_sql}
                ) as record
                full outer join (
                  select queued_since,
                         ids,
                         live_arguments,
                         next_arguments
                    from #{RuleMatch.table_name}, __ids
                   where rule_id = #{ActiveRecord::Base.connection.quote(id)}
                     and #{json_sql}
                ) as match on match.ids = record.ids
               where true
            on conflict(rule_id, ids) do update
              set queued_since = excluded.queued_since,
                  next_arguments = excluded.next_arguments
            returning id
        SQL
      end
    end

    def format_sql_conditions(pending_activations)
      return true if pending_activations.nil? || pending_activations.include?(:all)
      return false if pending_activations.empty?

      pending_activations.map do |pending_activation|
        ids = pending_activation.condition_terms.map { "q.__id_#{_1}" }
        sql_condition = "(#{ids.join(", ")}) in (select * from __ids)"
        json_condition = pending_activation.condition_terms.map do |term|
          "exists (select 1
                     from #{RuleMatchId.table_name}
                    where rule_id = #{ActiveRecord::Base.connection.quote(id)}
                      and rule_match_id = #{RuleMatch.table_name}.id
                      and name = #{ActiveRecord::Base.connection.quote(term)}
                      and record_id = __ids.#{term})"
        end.join(" and ")
        [pending_activation.condition_sql, sql_condition, json_condition]
      end
    end

    def logger
      ActiveRecordRules.logger
    end

    class ExecutionContext < SimpleDelegator
      def initialize(base, values)
        super(base)
        @values = values
      end

      def self.for_variables(names)
        Class.new(ExecutionContext) do
          names&.each do |name|
            sym_name = name.to_sym
            if instance_methods.include?(sym_name)
              raise "Bound variable #{sym_name} conflict with method in execution context"
            end

            define_method(sym_name) { @values[name] }
          end
        end
      end
    end
  end
end
