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
  # A Rule is provided updates by its related Condition nodes whenever
  # an object passes, or ceases to pass, its test. This allows for
  # incremental updates to the output.
  #
  # A Rule finds the other objects to process by looking into its
  # conditions' ConditionMatch objects to find the objects which
  # currently match the condition.
  class Rule < ActiveRecord::Base
    self.table_name = :arr__rules

    has_many :extractors
    has_many :conditions, through: :extractors
    has_many :rule_matches

    class RuleSyntaxError < StandardError; end

    def self.define_rule(definition_string)
      definition = Parser.new.definition.parse(definition_string, reporter: Parslet::ErrorReporter::Deepest.new)

      extractors = definition[:conditions].each_with_index.map do |condition_definition, index|
        constant_conditions = (condition_definition[:parts] || []).map do |cond|
          case cond
          in { name:, op:, rhs: { string: } }
            "#{name} #{op} #{string.to_s.to_json}"
          in { name:, op:, rhs: { number: } }
            "#{name} #{op} #{number}"
          in { name:, op:, rhs: { boolean: } }
            "#{name} #{op} #{boolean}"
          in { name:, op:, rhs: { nil: _ } }
            "#{name} #{op} nil"
          else
            nil
          end
        end.compact

        condition = Condition.find_or_initialize_by(
          match_class: condition_definition[:class_name].to_s,
          # We have to wrap the conditions in this fake object
          # because querying with an array at the toplevel turns
          # into an ActiveRecord IN query, which ruins everything.
          # Using an object here simplifies things a lot.
          match_conditions: { "clauses" => constant_conditions }
        )
        condition.validate!

        fields = (condition_definition[:parts] || [])
                 .select { _1[:rhs].nil? || !_1[:rhs][:name].nil? } # remove the constant conditions
                 .map { _1[:name].to_s }
                 .uniq

        Extractor.new(
          key: "cond#{index + 1}",
          condition: condition,
          fields: fields
        )
      end

      Rule.create!(
        extractors: extractors,
        name: definition[:name].to_s,
        definition: definition_string
      )
    end

    def activate(key, object, values)
      names, _, on_match_code = parsed_definition

      logger&.debug { "Rule(#{id}): activating with #{object.class}(#{object.id})" }

      fetch_ids_and_arguments_for(key, object, values).map do |ids, (arguments, _)|
        rule_matches.create!(ids: ids)
        logger&.info { "Rule(#{id}): matched for #{ids.to_json}" }
        logger&.debug { "Rule(#{id}): matched with arguments #{names.keys.zip(arguments).to_h.to_json}" }

        Object.new.instance_exec(*arguments, &on_match_code)
      end
    end

    def update(key, object, old_values, new_values)
      names, _, on_match_code, on_unmatch_code = parsed_definition

      current_matches = fetch_ids_and_arguments_for(key, object, new_values, old_values: old_values)
                        .map do |ids, (arguments, old_arguments)|
        if (match_record = rule_matches.find_by(ids: ids))
          logger&.info { "Rule(#{id}): re-matched for #{ids.to_json}" }
          logger&.debug { "Rule(#{id}): re-matched with arguments #{names.keys.zip(arguments).to_h.to_json}" }

          Object.new.instance_exec(*old_arguments, &on_unmatch_code)
        else
          match_record = rule_matches.create!(ids: ids)
          logger&.info { "Rule(#{id}): matched for #{ids.to_json}" }
          logger&.debug { "Rule(#{id}): matched with arguments #{names.keys.zip(arguments).to_h.to_json}" }
        end
        Object.new.instance_exec(*arguments, &on_match_code)

        # We return the match records, so update can know what to do with it.
        match_record
      end

      fetch_ids_and_arguments_for(key, object, old_values, exclude: current_matches).each do |ids, (arguments, _)|
        rule_matches.destroy_by(ids: ids)
        logger&.info { "Rule(#{id}): unmatched for #{ids.to_json} (set no longer matches rule)" }
        logger&.debug { "Rule(#{id}): unmatched with arguments #{names.keys.zip(arguments).to_h.to_json}" }
        Object.new.instance_exec(*arguments, &on_unmatch_code)
      end
    end

    def deactivate(key, object, values)
      names, _, _, on_unmatch_code = parsed_definition

      destroyed = rule_matches.destroy_by("ids->>? = ?", key, object.id)

      # Convert an array of hashes like [{'cond' => id}] into a hash
      # of arrays like {'cond'=>[id]}
      object_ids = Hash.new { _1[_2] = [] }
      destroyed.pluck(:ids).each do |ids|
        ids.each { object_ids[_1] << _2 }
      end

      arguments_by_ids = fetch_ids_and_arguments_for(key, object, values)

      destroyed.each do |record|
        arguments, = arguments_by_ids[record.ids]
        logger&.info { "Rule(#{id}): unmatched for #{record.ids.to_json} (entry removed by condition)" }
        logger&.debug { "Rule(#{id}): unmatched with arguments #{names.keys.zip(arguments).to_h.to_json}" }

        Object.new.instance_exec(*arguments, &on_unmatch_code)
      end
    end

    def parsed_definition
      @parsed_definition ||= begin
        parsed = Parser.new.definition.parse(definition,
                                             reporter: Parslet::ErrorReporter::Deepest.new)

        names = Hash.new { _1[_2] = [] }

        constraints = Set.new

        parsed[:conditions].each_with_index.map do |condition_definition, index|
          condition_definition[:parts].each do |cond|
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

        on_match_code = Object.new.instance_eval(<<~RUBY, __FILE__, __LINE__ + 1)
          # ->(in1, in2) {
          #   puts "Matching for \#{in1} \#{in2}"
          # }

          ->(#{names.keys.join(", ")}) {
            #{parsed[:on_match]&.pluck(:line)&.join("\n  ")}
          }
        RUBY

        on_unmatch_code = Object.new.instance_eval(<<~RUBY, __FILE__, __LINE__ + 1)
          # ->(in1, in2) {
          #   puts "Unmatching for \#{in1} \#{in2}"
          # }

          ->(#{names.keys.join(", ")}) {
            #{parsed[:on_unmatch]&.pluck(:line)&.join("\n  ")}
          }
        RUBY

        on_update_code = Object.new.instance_eval(<<~RUBY, __FILE__, __LINE__ + 1)
          # ->(in1, in2) {
          #   puts "Updating for \#{in1} \#{in2}"
          # }

          ->(#{names.keys.join(", ")}) {
            #{parsed[:on_update]&.pluck(:line)&.join("\n  ")}
          }
        RUBY

        [names, constraints, on_match_code, on_unmatch_code, on_update_code]
      end
    rescue Parslet::ParseFailed => e
      raise e.parse_failure_cause.ascii_tree
    end

    private

    def logger
      ActiveRecordRules.logger
    end

    def fetch_ids_and_arguments_for(key, object, values, exclude: nil, old_values: {})
      names, constraints, = parsed_definition

      matches = extractors.to_h { [_1.key, _1.extractor_matches] }.without(key)

      binds = []
      clauses = constraints.map do |op, lhs, rhs|
        case [lhs, rhs]
        in [[^key, left_field], [join_key, right_field]]
          binds << values[left_field]
          "? #{op} #{join_key}.\"values\"->>'#{right_field}'"

        in [[join_key, left_field], [^key, right_field]]
          binds << values[right_field]
          "#{join_key}.\"values\"->>'#{left_field}' #{op} ?"

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

      our_values, our_old_values, other_names = names.map do |name, definitions|
        if (definition = definitions.find { _1[0] == key })
          [[name, values[definition[1]]],
           [name, old_values[definition[1]]],
           nil]
        else
          definition = definitions.first
          [nil,
           nil,
           [name, "#{definition[0]}.\"values\"->>'#{definition[1]}'"]]
        end
      end.transpose.map(&:compact)

      query_result = ActiveRecord::Base.connection.select_all(<<~SQL.squish, nil, binds).rows
        select #{matches.keys.map { "#{_1}.entry_id" }.join(", ")}
               #{other_names.map(&:second).map { ", #{_1}" }.join}
          from #{matches.map { "(#{_2.to_sql}) as #{_1}" }.join(", ")}
         #{clauses.empty? ? "" : "where #{clauses.join(" and ")}"}
      SQL

      excluded_ids = exclude.pluck(:ids).to_set if exclude

      query_result.map do |row|
        ids = [
          [key, object.id],
          *matches.keys.zip(row[..matches.size])
        ].sort_by(&:first).to_h

        next if excluded_ids&.include?(ids)

        other_values = other_names.map(&:first).zip(row[matches.size..])
        final_values = (our_values + other_values).to_h
        old_final_values = (our_old_values + other_values).to_h

        [ids, [names.keys.map { final_values[_1] }, names.keys.map { old_final_values[_1] }]]
      end.compact.to_h
    end
  end
end
