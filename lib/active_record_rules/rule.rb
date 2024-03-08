# frozen_string_literal: true

module ActiveRecordRules
  # A representation of a production rule which matches objects
  # matching conditions and runs code when the rule begins to match or
  # ceases to match.
  #
  # See +Condition+ for a depiction of how this class relates to the
  # conditions. The broad idea is that Condition is responsible for
  # "simple" things (i.e. checks against constant values) and the Rule
  # is responsible for "complex" things (i.e. checks involving
  # multiple objects).
  #
  # A Rule is provided updates by its related Condition nodes (through
  # an Extractor) whenever an object passes, or ceases to pass, its
  # test. This allows for incremental updates to the output.
  #
  # A Rule finds the other objects to process by looking into its
  # extractor's ExtractorMatch objects to find the values to use in
  # conditions and as arguments.
  class Rule < ActiveRecord::Base
    self.table_name = :arr__rules

    # We order the extractors by key to ensure we always have a
    # consistent order when we use it below. This is important to make
    # it so that string comparison of JSON objects is equivalent to a
    # proper JSON comparison.
    has_many :extractors, -> { order(:key) }, dependent: :delete_all
    has_many :conditions, through: :extractors
    has_many :rule_matches, dependent: :delete_all

    class ValuesNotFound < StandardError; end

    def run_pending_executions
      parsed_definition => { names: }

      rule_matches.delete_by(awaiting_execution: "delete")

      rule_matches.where(awaiting_execution: "unmatch").in_batches do |batch|
        all_rows = batch.pluck(:ids, :stored_arguments)

        # Go through each record and run the unmatch code
        all_rows.map do |ids, old_values|
          arguments = names.keys.map { old_values[_1] }

          logger&.info { "Rule(#{id}): unmatched for #{ids.to_json}" }
          logger&.debug { "Rule(#{id}): unmatched with arguments #{pretty_arguments(arguments).to_json}" }

          execute_unmatch(arguments)
        end

        # Then remove them
        batch.delete_all
      end

      rule_matches.where(awaiting_execution: "update").in_batches do |batch|
        all_rows = batch.pluck(:ids, :stored_arguments)

        # Fetch all of the current values needed for this batch
        values_lookup = positive_extractors.to_h do |match|
          [match.key, match.condition_matches
                           .where(entry_id: all_rows.map(&:first).pluck(match.key))
                           .pluck(:entry_id, :stored_values)
                           .to_h]
        end

        # Go through each record and run the update code
        all_rows.map do |ids, old_values|
          old_arguments = names.keys.map { old_values[_1] }
          logger&.info { "Rule(#{id}): updated for #{ids.to_json}" }

          arguments = names.map do |_, (wrapped_expression)|
            values = values_lookup[wrapped_expression.key][ids[wrapped_expression.key]]
            raise ValuesNotFound unless values

            values[wrapped_expression.name]
          end

          logger&.debug do
            "Rule(#{id}): updating from #{pretty_arguments(old_arguments).to_json} " \
              "=> #{pretty_arguments(arguments).to_json}"
          end

          execute_update(old_arguments, arguments)
        rescue ValuesNotFound
          logger&.info do
            "Rule(#{id}): update scheduled, but couldn't find new values; ignoring."
          end
        end

        # Then mark them as being done
        batch.update_all(awaiting_execution: nil, stored_arguments: nil)
      end

      rule_matches.where(awaiting_execution: "match").in_batches do |batch|
        all_ids = batch.pluck(:ids)

        # Fetch all of the related values needed for this batch
        values_lookup = positive_extractors.to_h do |match|
          [match.key, match.condition_matches
                           .where(entry_id: all_ids.pluck(match.key))
                           .pluck(:entry_id, :stored_values)
                           .to_h]
        end

        # Go through each record and run the match code
        all_ids.map do |ids|
          logger&.info { "Rule(#{id}): matched for #{ids.to_json}" }
          arguments = names.map do |_, (wrapped_expression)|
            values = values_lookup[wrapped_expression.key][ids[wrapped_expression.key]]
            raise ValuesNotFound unless values

            values[wrapped_expression.name]
          end

          logger&.debug { "Rule(#{id}): matched with arguments #{pretty_arguments(arguments).to_json}" }

          execute_match(arguments)
        rescue ValuesNotFound
          logger&.info do
            "Rule(#{id}): match scheduled, but couldn't find new values; ignoring."
          end
        end

        # Then mark them as being done
        batch.update_all(awaiting_execution: nil)
      end
    end

    def ignore_pending_executions
      rule_matches.update_all(awaiting_execution: nil)
    end

    def activate(keys_to_ids = nil)
      parsed_definition => { names: }

      left_joins = positive_extractors.map do |extractor|
        " left join (#{extractor.condition_matches.to_sql}) as #{extractor.key} " \
        "on #{extractor.key}.entry_id = " + id_cast("match.ids->>'#{extractor.key}'")
      end
      names_pairs = names.map do |name, (wrapped_expression)|
        ["'#{name}'", wrapped_expression.to_sql("coalesce({}.previous_stored_values, {}.stored_values)", {})]
      end

      ids_clause = if keys_to_ids.nil?
                     "true"
                   elsif negative_extractors.any? { keys_to_ids.key?(_1.key) } # rubocop:disable Lint/DuplicateBranch
                     # If the updated objects are used in any negative
                     # conditions then we essentially need to
                     # re-evaluate everything.
                     # TODO: refine this substantially, if we can
                     "true"
                   elsif keys_to_ids.empty?
                     "false"
                   else
                     keys_to_ids.flat_map do |key, ids|
                       next unless positive_extractors.find { _1.key == key }

                       ["query.ids", "match.ids"].map do |field|
                         id_cast("#{field}->>'#{key}'") +
                           " in (#{ids.map { ActiveRecord::Base.connection.quote(_1) }.join(", ")})"
                       end
                     end.compact.join(" or ")
                   end

      # Run pure SQL to update existing records (i.e. do not load the
      # records themselves into Ruby).
      ActiveRecord::Base.connection.execute(<<~SQL.squish)
        insert into arr__rule_matches(rule_id, ids, awaiting_execution, stored_arguments)
          select #{ActiveRecord::Base.connection.quote(id)},
                 coalesce(query.ids, match.ids),
                 case
                   when query.ids is null then
                     #{RuleMatch.awaiting_executions["unmatch"]}
                   when match.ids is null then
                     #{RuleMatch.awaiting_executions["match"]}
                   when query.arguments = #{json_object_function}(#{names_pairs.flatten.join(",")}) then
                     null
                   else
                     #{RuleMatch.awaiting_executions["update"]}
                 end,
                 case
                   when match.ids is null then
                     null
                   when query.arguments = #{json_object_function}(#{names_pairs.flatten.join(",")}) then
                     null
                   else
                     #{json_object_function}(#{names_pairs.flatten.join(",")})
                 end
            from (#{all_matches_query(keys_to_ids)}) as query
            full outer join
              (#{rule_matches.to_sql}) as match
              on query.ids = match.ids
            #{left_joins.join}
           where #{ids_clause}
          on conflict(rule_id, ids) do update
            set "awaiting_execution" = (case
                                          when arr__rule_matches.awaiting_execution = #{RuleMatch.awaiting_executions["match"]}
                                               and excluded.awaiting_execution = #{RuleMatch.awaiting_executions["unmatch"]} then
                                            #{RuleMatch.awaiting_executions["delete"]}
                                          when arr__rule_matches.awaiting_execution in (#{RuleMatch.awaiting_executions["match"]},
                                                                                        #{RuleMatch.awaiting_executions["unmatch"]}) then
                                            arr__rule_matches.awaiting_execution
                                          else
                                            excluded.awaiting_execution
                                        end),
                "stored_arguments" = (case
                                        when arr__rule_matches.awaiting_execution in (#{RuleMatch.awaiting_executions["match"]},
                                                                                      #{RuleMatch.awaiting_executions["unmatch"]}) then
                                          arr__rule_matches.stored_arguments
                                        else
                                          excluded.stored_arguments
                                      end)
      SQL
    end

    def unmatch_all
      parsed_definition => { names: }
      left_joins = extractors.map do |extractor|
        " left join (#{extractor.condition_matches.to_sql}) as #{extractor.key} " \
        "on #{extractor.key}.entry_id = " + id_cast("match.ids->>'#{extractor.key}'")
      end
      names_pairs = names.map do |name, (wrapped_expression)|
        ["'#{name}'", wrapped_expression.to_sql("coalesce({}.previous_stored_values, {}.stored_values)", {})]
      end

      # Run pure SQL to update existing records (i.e. do not load the
      # records themselves into Ruby).
      ActiveRecord::Base.connection.execute(<<~SQL.squish)
        insert into arr__rule_matches(rule_id, ids, awaiting_execution, stored_arguments)
          select #{ActiveRecord::Base.connection.quote(id)},
                 match.ids,
                 #{RuleMatch.awaiting_executions["unmatch"]},
                 #{json_object_function}(#{names_pairs.flatten.join(",")})
            from (#{rule_matches.to_sql}) as match
            #{left_joins.join}
           where true
          on conflict(rule_id, ids) do update
            set "awaiting_execution" = (case
                                          when arr__rule_matches.awaiting_execution is null then
                                            excluded.awaiting_execution
                                          when arr__rule_matches.awaiting_execution = #{RuleMatch.awaiting_executions["match"]} then
                                            #{RuleMatch.awaiting_executions["delete"]}
                                          else
                                            excluded.awaiting_execution
                                        end),
                "stored_arguments" = coalesce(arr__rule_matches.stored_arguments, excluded.stored_arguments)
      SQL
    end

    private

    def json_object_function
      if ActiveRecordRules.dialect == :sqlite
        "json_object"
      elsif ActiveRecordRules.dialect == :postgres
        "jsonb_build_object"
      else
        raise "Unknown dialect: #{ActiveRecordRules.dialect}"
      end
    end

    def id_cast(object)
      if ActiveRecordRules.dialect == :sqlite
        object # no need to cast in sqlite!
      elsif ActiveRecordRules.dialect == :postgres
        "(#{object}) :: #{ActiveRecordRules.id_type}"
      else
        raise "Unknown dialect: #{ActiveRecordRules.dialect}"
      end
    end

    def positive_extractors = extractors.reject(&:negated)
    def negative_extractors = extractors.select(&:negated)

    def logger
      ActiveRecordRules.logger
    end

    WrappedExpression = Struct.new(:comparison, :klass, :key) do
      def to_sql(field, bindings)
        comparison.to_sql(klass, key ? field.gsub("{}", key) : nil, bindings)
      end

      def name = comparison.name
    end

    def parsed_definition
      @parsed_definition ||= begin
        names = Hash.new { _1[_2] = [] }

        clauses = Parse.constraints(variable_conditions).each_with_index.flat_map do |constraint, index|
          if constraint.is_a?(Parse::Ast::Comparison)
            constraint.bound_variables.each { names[_1] << WrappedExpression.new(_2, nil, nil) }
            next [WrappedExpression.new(constraint, nil, nil)]
          end

          match_class = constraint.class_name.constantize
          constraint.clauses.map do |clause|
            unless constraint.negated
              # Positive clauses bind names that can be referred to in
              # other clauses.
              clause.bound_variables.each do |name, value|
                names[name] << WrappedExpression.new(value, match_class, "cond#{index + 1}")
              end
            end
            WrappedExpression.new(clause, match_class, "cond#{index + 1}")
          end
        end

        { names: names,
          clauses: clauses }
      end
    end

    def on_match_proc
      parsed_definition => { names: }
      @on_match_proc ||= Object.new.instance_eval(<<~RUBY, __FILE__, __LINE__ + 1)
        # ->(*arguments) {
        #   code to run when matching
        # }
        ->(#{names.keys.join(", ")}) {
          #{on_match}
        }
      RUBY
    end

    def on_unmatch_proc
      parsed_definition => { names: }
      @on_unmatch_proc ||= Object.new.instance_eval(<<~RUBY, __FILE__, __LINE__ + 1)
        # ->(*arguments) {
        #   code to run when unmatching
        # }
        ->(#{names.keys.join(", ")}) {
          #{on_unmatch}
        }
      RUBY
    end

    def on_update_proc
      return unless on_update

      parsed_definition => { names: }
      @on_update_proc ||= Object.new.instance_eval(<<~RUBY, __FILE__, __LINE__ + 1)
        # ->(*arguments) {
        #   code to run when updating
        # }
        ->(#{names.keys.join(", ")}) {
          #{on_update}
        }
      RUBY
    end

    def pretty_arguments(arguments)
      parsed_definition => { names: }
      names.keys.zip(arguments).to_h
    end

    def execute_match(args)
      context.instance_exec(*args, &on_match_proc)
    end

    ArgumentPair = Struct.new(:old, :new)

    def execute_update(old_args, new_args)
      if on_update_proc
        arg_pairs = old_args.zip(new_args).map { ArgumentPair.new(_1, _2) }
        context.instance_exec(*arg_pairs, &on_update_proc)
      else
        context.instance_exec(*old_args, &on_unmatch_proc)
        context.instance_exec(*new_args, &on_match_proc)
      end
    end

    def execute_unmatch(args)
      context.instance_exec(*args, &on_unmatch_proc)
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

    def all_matches_query(keys_to_ids)
      parsed_definition => { names:, clauses: }

      bindings = names.transform_values do |wrapped_expression,|
        wrapped_expression.to_sql("{}.stored_values", {})
      end

      matches = positive_extractors.to_h do |extractor|
        [extractor.key, extractor.condition_matches.to_sql]
      end

      negative_joins = negative_extractors.to_h do |extractor|
        on_clause = clauses.map do |wrapped_expression|
          next unless extractor.key == wrapped_expression.key

          wrapped_expression.to_sql("{}.stored_values", bindings)
        end.compact.join(" and ")

        [extractor.key,
         " left join (#{extractor.condition_matches.to_sql}) as #{extractor.key} on #{on_clause}"]
      end

      ids_sql = matches.keys.map do |name|
        "'#{name}', #{name}.entry_id"
      end.join(", ")

      names_pairs = names.map do |name, (wrapped_expression)|
        ["'#{name}'", wrapped_expression.to_sql("{}.stored_values", bindings)]
      end

      ids_clause =
        if keys_to_ids && (keys_to_ids.keys.to_set < matches.keys.to_set)
          keys_to_ids&.map do |key, ids|
            next unless matches.key?(key) # I'm not sure how to write this filter for negative clauses

            "#{key}.entry_id in (#{ids.map { ActiveRecord::Base.connection.quote(_1) }.join(", ")})"
          end&.compact&.join(" or ")
        end

      where_clause = [
        ids_clause && "(#{ids_clause})",

        *matches.keys.map { "#{_1}.stored_values is not null" },

        *clauses.map do |wrapped_expression|
          next unless wrapped_expression.key.nil? || matches.key?(wrapped_expression.key)

          wrapped_expression.to_sql("{}.stored_values", bindings)
        end,

        *negative_joins.map do |key, _|
          "#{key}.id is null"
        end
      ].compact.join(" and ")

      <<~SQL.squish
        select #{json_object_function}(#{ids_sql}) as ids,
               #{json_object_function}(#{names_pairs.flatten.join(",")}) as arguments
          from #{matches.map { "(#{_2}) as #{_1}" }.join(",")}
               #{negative_joins.map(&:second).join}
         #{where_clause.presence && "where #{where_clause}"}
      SQL
    end
  end
end
