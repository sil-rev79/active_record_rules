# frozen_string_literal: true

require "active_record_rules/ast/node"
require "active_record_rules/attribute_tracker"
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

      def relevant_attributes_by_class
        @relevant_attributes_by_class ||= begin
          tracker = AttributeTracker.new
          @constraints.each { _1.record_relevant_attributes(tracker) }
          tracker.attributes_by_class
        end
      end

      def affected_ids_sql(klass, previous, current)
        return Set.new if previous.nil? && current.nil?
        return Set.new if previous == current

        relevant = previous.nil? ||
                   current.nil? ||
                   @constraints.any? { _1.relevant_change?(klass, previous, current) }
        return Set.new unless relevant

        pending_activations = Set.new

        populate_table_edges!

        @start_tables[klass].each do |table|
          if @target_tables.include?(table)
            # No need to find a path if the record we're changing is
            # one of our ground ids. Nice and easy.
            [previous, current].each do |attributes|
              next unless attributes

              value = ActiveRecord::Base.connection.quote(attributes["id"])
              pending_activations << Rule::PendingActivation.new([table], "select #{id_cast(value, klass)} as #{table}")
            end
          else
            # If we're not immediately in the right place, then we
            # need to find a path to where we're going. We do a
            # breadth first search until we have either (a) found a
            # path to *all* target tables, or (b) run out of paths to
            # explore.
            #
            # Once we have that, we construct a SQL query based on the
            # paths we've found. If we find no paths, then we have to
            # invalidate *all* matches.
            target_tables = Set.new(@target_tables)
            candidates = []
            done = Set.new([table])
            @edges[table].each do |field, local_edges|
              local_edges.each do |edge|
                candidates << [edge, [[edge, TableField.new(table, field)]]]
              end
            end

            paths = []
            while (item, path = candidates.shift)
              next unless done.add?(item.table)

              if target_tables.include?(item.table)
                paths << path
                target_tables.delete(item.table)
                break if target_tables.empty?
              end

              @edges[item.table].each do |field, local_edges|
                local_edges.each do |edge|
                  candidates << [edge, [[edge, TableField.new(item.table, field)]] + path]
                end
              end
            end

            # If we do a search and we fail to find a path, then we just
            # have to invalidate everything. Note that this *returns*
            # which breaks out of this entire loop.
            #
            # This is relatively expensive, so hopefully it doesn't
            # happen often!
            return Set.new([:all]) if paths.empty?

            selections = {}
            tables = Hash.new { _1[_2] = [] }
            wheres = []

            paths.each do |full_path|
              first, = full_path.first
              last, dead_last = full_path.last

              if first == last && first.field == "id"
                # A single-segment path connecting to "id" doesn't
                # really need to hit a table at all, we can just return
                # the values we already know about.
                selections[first.table] = lambda { |attributes|
                  ActiveRecord::Base.connection.quote(
                    attributes[dead_last.field]
                  )
                }
              else
                selections[first.table] = ->(_) { "#{first.table}.id" }

                tables[first.table] ||= []
                full_path[...-1].each do |from, to|
                  tables[to.table] << "#{from.table}.#{from.field} = #{to.table}.#{to.field}"
                end

                wheres << lambda { |attributes|
                  op = (attributes[dead_last.field].nil? ? "is" : "=")
                  value = ActiveRecord::Base.connection.quote(attributes[dead_last.field])
                  "#{last.table}.#{last.field} #{op} #{value}"
                }
              end
            end

            [previous, current].each do |attributes|
              next if attributes.nil?

              selections_sql = selections.map do |name, maker|
                "#{maker.call(attributes)} as #{name}"
              end.uniq.join(",\n       ")

              tables_sql = tables.sort_by { _2.length }.map do |name, ons|
                if ons.empty?
                  " cross join #{@internal_table_names[name]} as #{name}"
                else
                  [
                    " inner join #{@internal_table_names[name]} as #{name}",
                    "         on #{ons.uniq.join("\n     and ")}"
                  ].join("\n")
                end
              end.uniq.join("\n")
              unless tables_sql.empty? || tables_sql.start_with?(" cross join ")
                raise "Invalid query generated: do all of the joins have 'on' conditions somehow?"
              end

              tables_sql = tables_sql[(" cross join ".size)..]

              wheres_sql = wheres.map do |maker|
                maker.call(attributes)
              end.uniq.join("\n   and ")

              pending_activations << Rule::PendingActivation.new(
                selections.keys.map { @external_table_names[_1] },
                [
                  "select #{selections_sql}",
                  ("  from #{tables_sql}" unless tables.empty?),
                  (" where #{wheres_sql}" unless wheres.empty?)
                ].compact.join("\n")
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

      def populate_table_edges!
        return if @edges

        populate_query_parts!

        table_bindings = Hash.new { _1[_2] = [] }

        to_do = constraints.dup.map { [_1, true] }
        table_index = 0
        @target_tables = []
        @start_tables = Hash.new { _1[_2] = [] }
        @internal_table_names = {}
        @external_table_names = {}
        i = 0
        while (constraint, top_level = to_do.shift)
          case constraint
          in Aggregate(aggregated_constraints)
            to_do += aggregated_constraints.map { [_1, false] }
          in Negation(negated_constraints)
            to_do += negated_constraints.map { [_1, false] }
          in RecordMatcher(match_klass, clauses)
            table_name = "#{match_klass.table_name}_#{table_index += 1}"
            @internal_table_names[table_name] = match_klass.table_name
            @external_table_names[table_name] = @table_names[i]
            i += 1

            @target_tables << table_name if top_level
            @start_tables[match_klass] << table_name

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

        @edges = Hash.new { _1[_2] = {} } # table => { field => [TableField ...] }
        table_bindings.each_value do |table_fields|
          table_fields.each do |table_field|
            @edges[table_field.table][table_field.field] = table_fields.reject { _1 == table_field }
          end
        end
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

      def id_cast(sql, klass)
        case ActiveRecordRules.dialect
        in :sqlite
          sql
        in :postgres
          "#{sql} :: #{klass.attribute_types["id"].type}"
        end
      end
    end
  end
end
