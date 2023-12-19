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

    has_many :extractor_keys, dependent: :delete_all
    has_many :extractors, through: :extractor_keys
    has_many :conditions, through: :extractors
    has_many :rule_matches, dependent: :delete_all

    class RuleSyntaxError < StandardError; end

    # @param key [String] The Extractor key that is being updated
    # @param objects [Hash{String => Hash}] An {id => values} mapping of objects to field values
    def activate(key, objects, trigger_rules: true)
      matches = fetch_ids_and_arguments_for(key, objects)
      if matches.any?
        rule_matches.insert_all!(
          matches.map do |ids, _|
            { ids: ids }
          end
        )
      end

      matches.map do |ids, (arguments, _)|
        logger&.info { "Rule(#{id}): matched for #{ids.to_json}" }
        logger&.debug { "Rule(#{id}): matched with arguments #{pretty_arguments(arguments).to_json}" }

        execute_match(arguments) if trigger_rules
      end
    end

    # @param key [String] The Extractor key that is being updated
    # @param old_objects [Hash{String => Hash}] An {id => values} mapping of objects to field values
    # @param new_objects [Hash{String => Hash}] An {id => values} mapping of objects to field values
    def update(key, old_objects, new_objects, trigger_rules: true)
      all_matches = fetch_ids_and_arguments_for(key, new_objects, old_values: old_objects)

      # We have to construct an Arel here for the query because
      # otherwise ActiveRecord double-encodes our hashes as JSON.
      # That is: rule_matches.where(ids: all_matches.keys) writes a
      # condition like "ids in (?, ?, ...)" where the parameters are
      # bound to "\"{\\\"key\\\":10}\"". Note that this is similar to
      # doing ids.to_json.to_json, which means the database can't find
      # the right records.
      #
      # Arel correctly encodes the parameter as "{\"key\":10}".
      already_matched_ids = rule_matches.where(RuleMatch.arel_table[:ids].in(all_matches.keys)).pluck(:ids).to_set

      updating, matching = all_matches.partition do |ids, _|
        already_matched_ids.include?(ids)
      end
      if matching.any?
        rule_matches.insert_all!(
          matching.map do |ids, _|
            { ids: ids }
          end
        )
      end

      unmatching = fetch_ids_and_arguments_for(key, old_objects, exclude_ids: already_matched_ids)
      # See comment above for why we're dropping to Arel here.
      rule_matches.delete_by(RuleMatch.arel_table[:ids].in(unmatching.keys))

      matching.each do |ids, (arguments, _)|
        logger&.info { "Rule(#{id}): matched for #{ids.to_json}" }
        logger&.debug { "Rule(#{id}): matched with arguments #{pretty_arguments(arguments).to_json}" }
        execute_match(arguments) if trigger_rules
      end

      updating.each do |ids, (arguments, old_arguments)|
        logger&.info { "Rule(#{id}): re-matched for #{ids.to_json}" }
        logger&.debug { "Rule(#{id}): re-matched with arguments #{pretty_arguments(arguments).to_json}" }
        execute_update(old_arguments, arguments) if trigger_rules
      end

      unmatching.each do |ids, (arguments, _)|
        logger&.info { "Rule(#{id}): unmatched for #{ids.to_json} (set no longer matches rule)" }
        logger&.debug { "Rule(#{id}): unmatched with arguments #{pretty_arguments(arguments).to_json}" }
        execute_unmatch(arguments) if trigger_rules
      end
    end

    # @param key [String] The Extractor key that is being updated
    # @param objects [Hash{String => Hash}] An {id => values} mapping of objects to field values
    def deactivate(key, objects, trigger_rules: true)
      destroyed_ids = rule_matches.where("ids->>? = ?", key, objects.keys).pluck(:ids)
      rule_matches.delete_by("ids->>? = ?", key, objects.keys)
      arguments_by_ids = fetch_ids_and_arguments_for(key, objects)

      destroyed_ids.each do |ids|
        arguments, = arguments_by_ids[ids]
        logger&.info { "Rule(#{id}): unmatched for #{ids.to_json} (entry removed by condition)" }
        logger&.debug { "Rule(#{id}): unmatched with arguments #{pretty_arguments(arguments).to_json}" }

        execute_unmatch(arguments) if trigger_rules
      end
    end

    def unmatch_all
      arguments_by_ids = fetch_all_ids_and_arguments
      deleted_ids = rule_matches.pluck(:ids)
      rule_matches.delete_all

      deleted_ids.each do |ids|
        arguments = arguments_by_ids[ids]
        logger&.info { "Rule(#{id}): unmatched for #{ids.to_json} (rule deleted)" }
        logger&.debug { "Rule(#{id}): unmatched with arguments #{pretty_arguments(arguments).to_json}" }

        execute_unmatch(arguments)
      end
    end

    private

    def logger
      ActiveRecordRules.logger
    end

    def parsed_definition
      @parsed_definition ||= begin
        parsed = Parser.new.conditions.parse(
          variable_conditions,
          reporter: Parslet::ErrorReporter::Deepest.new
        )

        names = Hash.new { _1[_2] = [] }

        constraints = Set.new

        parsed.each_with_index.map do |condition_definition, index|
          (condition_definition[:parts] || []).each do |cond|
            case cond
            in { name:, op: "=", rhs: { name: rhs } }
              names[rhs.to_s] << ["cond#{index + 1}", name.to_s]
            in { name:, op:, rhs: { number: rhs } }
              constraints << [op, ["cond#{index + 1}", name.to_s], rhs.to_i]
            in { name:, op:, rhs: { string: rhs } }
              constraints << [op, ["cond#{index + 1}", name.to_s], rhs.to_s]
            in { name:, op:, rhs: { boolean: rhs } }
              constraints << [op, ["cond#{index + 1}", name.to_s], rhs.to_s == "true"]
            in { name:, op:, rhs: { nil: _ } }
              constraints << [op, ["cond#{index + 1}", name.to_s], nil]
            in { name:, op:, rhs: { name: rhs } }
              fields = names[rhs.to_s]
              raise "Right-hand side name does not have a value in constraint: #{name} #{op} #{fields}" if fields.empty?

              fields.each do |field|
                constraints << [op, ["cond#{index + 1}", name.to_s], field]
              end
            in { name: }
              names[name.to_s] << ["cond#{index + 1}", name.to_s]
            else
              raise "Unknown constraint format: #{cond}"
            end
          end
        end

        names.each_value do |fields|
          fields[1..].zip(fields).each do |lhs, rhs|
            constraints << ["=", lhs, rhs]
          end
        end

        { names: names,
          constraints: constraints }
      end
    rescue Parslet::ParseFailed => e
      raise e.parse_failure_cause.ascii_tree
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
      if on_update
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

    def fetch_ids_and_arguments_for(key, objects, exclude_ids: nil, old_values: {})
      parsed_definition => { names:, constraints: }

      binds = []

      matches = extractor_keys.to_h do |match|
        if match.key == key
          rows = objects.map do |object_id, values|
            binds << object_id
            binds << values.to_json
            "(?, ?)"
          end
          [match.key, "values #{rows.join(", ")}"]
        else
          [match.key, match.extractor_matches.to_sql]
        end
      end

      close_names = names.transform_values do |definitions|
        if (definition = definitions.find { _1[0] == key })
          definition[1] # get the field name
        end
      end.compact

      other_names = names.without(*close_names.keys).transform_values do |definition,|
        "#{definition[0]}.\"values\"->>'#{definition[1]}'"
      end.to_a

      clauses = constraints.map do |op, lhs, rhs|
        case [lhs, rhs]
        in [[left_key, left_field], [right_key, right_field]]
          "#{left_key}.\"values\"->>'#{left_field}' #{op} #{right_key}.\"values\"->>'#{right_field}'"

        else
          # The above represent all the clause formats that are
          # relationships between objects. The only things that remain
          # are constant clauses, which have already been handled by
          # the Condition object record activation process, so we can
          # ignore them here.
          nil
        end
      end.compact

      where_clause = clauses.join(" and ")

      query_result = ActiveRecord::Base.connection.select_all(<<~SQL.squish, nil, binds).rows
        with #{key}(entry_id, "values") as (#{matches[key]})
        select #{matches.keys.map { "#{_1}.entry_id" }.join(", ")}
               #{other_names.map(&:second).map { ", #{_1}" }.join}
          from #{key}#{matches.without(key).map { ", (#{_2}) as #{_1}" }.join}
         #{where_clause.presence && "where #{where_clause}"}
      SQL

      query_result.map do |row|
        ids = matches.keys.zip(row[..matches.size]).sort_by(&:first).to_h

        # TODO: add this to the WHERE clause with JSON_OBJECT and NOT IN
        next if exclude_ids&.include?(ids)

        other_values = other_names.map(&:first).zip(row[matches.size..]).to_h

        our_values = objects[ids[key]]
        our_old_values = old_values[ids[key]]

        final_values = other_values.merge(close_names.transform_values { our_values[_1] })
        old_final_values = if our_old_values
                             other_values.merge(close_names.transform_values { our_old_values[_1] })
                           else
                             {}
                           end

        [ids, [names.keys.map { final_values[_1] }, names.keys.map { old_final_values[_1] }]]
      end.compact.to_h
    end

    # This is a simplification of `fetch_ids_and_arguments_for',
    # above. I'm sure there's some helpful refactoring of them that
    # could be done, but I'll have to return to it later.
    def fetch_all_ids_and_arguments
      parsed_definition => { names:, constraints: }

      matches = extractor_keys.to_h do |match|
        [match.key, match.extractor_matches.to_sql]
      end

      sql_names = names.transform_values do |definition,|
        "#{definition[0]}.\"values\"->>'#{definition[1]}'"
      end.to_a

      clauses = constraints.map do |op, lhs, rhs|
        case [lhs, rhs]
        in [[left_key, left_field], [right_key, right_field]]
          "#{left_key}.\"values\"->>'#{left_field}' #{op} #{right_key}.\"values\"->>'#{right_field}'"

        else
          # The above represent all the clause formats that are
          # relationships between objects. The only things that remain
          # are constant clauses, which have already been handled by
          # the Condition object record activation process, so we can
          # ignore them here.
          nil
        end
      end.compact

      where_clause = clauses.join(" and ")

      query_result = ActiveRecord::Base.connection.select_all(<<~SQL.squish, nil).rows
        select #{matches.keys.map { "#{_1}.entry_id" }.join(", ")}
               #{sql_names.map(&:second).map { ", #{_1}" }.join}
          from #{matches.map { "(#{_2}) as #{_1}" }.join(",")}
         #{where_clause.presence && "where #{where_clause}"}
      SQL

      query_result.to_h do |row|
        ids = matches.keys.zip(row[..matches.size]).sort_by(&:first).to_h

        values = sql_names.map(&:first).zip(row[matches.size..]).to_h

        [ids, names.keys.map { values[_1] }]
      end
    end
  end
end
