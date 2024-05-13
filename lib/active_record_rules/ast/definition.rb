# frozen_string_literal: true

require "active_record_rules/ast/node"
require "active_record_rules/query_definer"

module ActiveRecordRules
  module Ast
    class Definition < Node
      attr_reader :name, :constraints, :on_match, :on_update, :on_unmatch

      def initialize(name, constraints, on_match, on_update, on_unmatch)
        super()
        @name = name
        @constraints = constraints
        @on_match = on_match
        @on_update = on_update
        @on_unmatch = on_unmatch
      end

      def to_query_sql
        populate_query_parts!
        @query_sql
      end

      def affected_ids_sql(klass, previous, current)
        return Set.new if previous.nil? && current.nil?
        return Set.new if previous == current

        populate_query_parts!

        table_bindings = Hash.new { _1[_2] = [] }

        to_do = constraints.dup.map { [_1, true] }
        table_index = 0
        target_tables = []
        start_tables = []
        table_names = {}
        external_table_names = {}
        i = 0
        while (constraint, top_level = to_do.shift)
          case constraint
          in Aggregate(aggregated_constraints)
            to_do += aggregated_constraints.map { [_1, false] }
          in Negation(negated_constraints)
            to_do += negated_constraints.map { [_1, false] }
          in RecordMatcher(match_klass, clauses)
            table_name = "#{match_klass.table_name}_#{table_index += 1}"
            table_names[table_name] = match_klass.table_name
            external_table_names[table_name] = @table_names[i]
            i += 1

            target_tables << table_name if top_level
            start_tables << table_name if klass == match_klass

            clauses.each do |clause|
              case clause
              in Comparison(Variable(lhs), "=", RecordField(rhs))
                table_bindings[lhs] << TableField.new(table_name, rhs)
              in Comparison(RecordField(lhs), "=", Variable(rhs))
                table_bindings[rhs] << TableField.new(table_name, lhs)
              else
                # Recurse into the LHS and RHS to find other relevant tables.
                to_do << [lhs, false]
                to_do << [rhs, false]
              end
            end
          in Comparison(lhs, _, rhs)
            # Recurse into the LHS and RHS to find other relevant tables.
            to_do << [lhs, false]
            to_do << [rhs, false]
          else
            # we're not handling anything else
            nil
          end
        end

        equivalence_sets = table_bindings.values

        pending_activations = Set.new
        start_tables.each do |table|
          if target_tables.include?(table)
            if previous
              pending_activations << Rule::PendingActivation.new([table], "select #{previous["id"]} as #{table}")
            end
            if current
              pending_activations << Rule::PendingActivation.new([table], "select #{current["id"]} as #{table}")
            end
          else
            candidates = []
            done = Set.new([table])
            equivalence_sets.each do |set|
              next unless (entry = set.find { _1.table == table })

              set.map do |item|
                candidates << [item, [[item, entry]]] unless item.table == entry.table
              end
            end

            final_path = nil
            while (item, path = candidates.shift)
              next unless done.add?(item.table)

              if target_tables.include?(item.table)
                final_path = path
                break
              end

              equivalence_sets.each do |set|
                next unless (entry = set.find { _1.table == item.table })

                set.map do |next_item|
                  candidates << [next_item, [[next_item, entry]] + path] unless next_item.table == entry.table
                end
              end
            end

            # If we do a search and we fail to find a path, then we just
            # have to invalidate everything. Note that this *returns*
            # which breaks out of this entire loop.
            return Set.new([:all]) if final_path.nil? || final_path.empty?

            first, = final_path.first
            last, dead_last = final_path.last
            query_base = [
              "select #{first.table}.id as #{first.table}",
              "  from #{table_names[first.table]} as #{first.table}",
              *final_path[...-1].flat_map do |from, to|
                [" inner join #{table_names[to.table]} as #{to.table}",
                 "         on #{from.table}.#{from.field} = #{to.table}.#{to.field}"]
              end
            ].join("\n")

            unless previous.nil?
              op = (previous[dead_last.field].nil? ? "is" : "=")
              value = ActiveRecord::Base.connection.quote(previous[dead_last.field])
              pending_activations << Rule::PendingActivation.new(
                [external_table_names[first.table]],
                query_base +
                "\n where #{last.table}.#{last.field} #{op} #{value}"
              )
            end

            unless current.nil?
              op = (current[dead_last.field].nil? ? "is" : "=")
              value = ActiveRecord::Base.connection.quote(current[dead_last.field])
              pending_activations << Rule::PendingActivation.new(
                [external_table_names[first.table]],
                query_base +
                "\n where #{last.table}.#{last.field} #{op} #{value}"
              )
            end
          end
        end

        pending_activations
      end

      def bound_names
        @bound_names ||= constraints.map(&:bound_names).reduce(&:+)
      end

      def unparse
        on_match = @on_match && "on match\n  #{@on_match.split("\n").join("\n  ")}\n"
        on_update = @on_update && "on update\n  #{@on_update.split("\n").join("\n  ")}\n"
        on_unmatch = @on_unmatch && "on unmatch\n  #{@on_unmatch.split("\n").join("\n  ")}\n"
        [
          "rule #{@name}",
          "  #{@constraints.map(&:unparse).join("\n  ")}",
          "#{on_match}#{on_update}#{on_unmatch}"
        ].join("\n")
      end

      private

      TableField = Struct.new(:table, :field)

      def populate_query_parts!
        return if @query_sql

        query_definer = QueryDefiner.new
        constraints.each do |constraint|
          emitter = constraint.to_query(query_definer)
          query_definer.add_condition(&emitter) if emitter
        end

        @table_names = query_definer.tables.keys.to_a
        @id_names, @other_names = query_definer.bindings.keys.partition { _1.start_with?("__id_") }
        @query_sql = <<~SQL
          select #{json_sql(@id_names)} as ids,
                 #{json_sql(@other_names)} as arguments
            from (
              #{query_definer.to_sql.split("\n").join("\n    ")}
            ) as q
        SQL
      end

      def json_sql(names)
        args = names.map { "'#{remove_id_prefix(_1)}', #{_1}" }.join(", ")
        if ActiveRecordRules.dialect == :sqlite
          "json_object(#{args})"
        elsif ActiveRecordRules.dialect == :postgres
          "jsonb_build_object(#{args})"
        else
          raise "Unknown dialect: #{ActiveRecordRules.dialect}"
        end
      end

      def remove_id_prefix(string)
        if string.start_with?("__id_")
          string[5..]
        else
          string
        end
      end
    end
  end
end
