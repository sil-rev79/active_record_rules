# frozen_string_literal: true

require "active_record_rules/ast/node"
require "active_record_rules/attribute_tracker"
require "active_record_rules/query_definer"

module ActiveRecordRules
  module Ast
    class ConstraintSet < Node
      attr_reader :constraints

      def initialize(constraints)
        super()
        @constraints = constraints
      end

      def extract_id_variables
        vars = @constraints.select { _1.is_a?(RecordMatcher) }.map(&:extract_id_variables).reduce({}, &:merge)
        # Once we've extracted the simple stuff, run through the
        # expressions.
        @constraints.reduce(vars) do |vars, constraint|
          case constraint
          in BinaryOperatorExpression(Variable(name), "=", expr)
            vars.merge(expr.id_paths(vars).transform_keys { [ name ] + _1 })
          in BinaryOperatorExpression(expr, "=", Variable(name))
            vars.merge(expr.id_paths(vars).transform_keys { [ name ] + _1 })
          else
            vars
          end
        end
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

      def id_names_and_types
        populate_query_parts!

        @id_names.map { _1.delete_prefix("__id_") }.zip(@constraints.to_a.select { _1.is_a?(Ast::RecordMatcher) }.map(&:klass))
      end

      def affected_ids_sql(klass, previous, current)
        return Set.new if previous.nil? && current.nil?
        return Set.new if previous == current

        relevant = previous.nil? ||
                   current.nil? ||
                   @constraints.any? { _1.relevant_change?(klass, previous, current) }
        return Set.new unless relevant

        populate_table_edges!

        pending_activations = Set.new

        @source_vertices[klass.table_name].each do |table|
          @graphs.each_with_index do |graph, i|
            paths = graph.find_paths([ table ], @sink_vertices)

            [ previous, current ].each do |attributes|
              next unless attributes

              selections = Hash.new { _1[_2] = [] }
              froms = Set.new
              wheres = Set.new
              paths.each do |path|
                case path
                in [{ table_name:, table_alias: }]
                  # If the path has no edges, then we can just return
                  # our id directly, because we know what we're
                  # looking at.
                  value = ActiveRecord::Base.connection.quote(attributes["id"])
                  selections[table_alias] << id_cast(value, klass)

                in [_, [[_, field_name, _], [target_table_alias, "id", _]], _] unless attributes[field_name].nil?
                  # If the path has a single edge joining onto the id
                  # of another table, we can avoid making any joins
                  # and just look up the id directly. This ends up
                  # being important for deletion, because we might not
                  # have a join record that we can use any more.
                  value = ActiveRecord::Base.connection.quote(attributes[field_name])
                  selections[target_table_alias] << id_cast(value, klass)

                in [_, [[_, base_field_name, _], [join_alias, join_field, join_nullable]], *tail, last_table]
                  # If the path has more than one edge, then we have
                  # to write a query that pulls in all the tables we
                  # need. We combine all the tables with CROSS JOINs,
                  # and write a single WHERE clause to filter them.
                  # We're relying on the database engine to optimise
                  # this sensibly.

                  # First we write a WHERE clause from our attribute
                  # to the next table. We handle this specially to
                  # avoid having to query for our own table.
                  our_sql = ActiveRecord::Base.connection.quote(attributes[base_field_name])
                  wheres << gen_eq(
                    QueryDefiner::SqlExpr.new(our_sql, attributes[base_field_name].nil?),
                    QueryDefiner::SqlExpr.new("#{join_alias}.#{join_field}", join_nullable)
                  ).delete_suffix(" is true")

                  # Then we iterate through the path, adding tables
                  # and conditions as we get to them
                  tail.each do |item|
                    case item
                    in { table_name:, table_alias: }
                      froms << "#{table_name} as #{table_alias}"
                    in [[left_alias, left_name, left_nullable], [right_alias, right_name, right_nullable]]
                      lhs = QueryDefiner::SqlExpr.new("#{left_alias}.#{left_name}", left_nullable)
                      rhs = QueryDefiner::SqlExpr.new("#{right_alias}.#{right_name}", right_nullable)
                      # The "is true" is redundant for our conditions
                      # (where NULL is treated as false), but leaving
                      # it here causes Postgres to not use indexes.
                      # Strip it off for performance.
                      wheres << gen_eq(lhs, rhs).delete_suffix(" is true")
                    end
                  end

                  # Then we add the table for our last join, and
                  # select its id.
                  froms << "#{last_table[:table_name]} as #{last_table[:table_alias]}"
                  selections[last_table[:table_alias]] << "#{last_table[:table_alias]}.id"
                end
              end

              next if selections.empty?

              selections_sql = selections.map { "#{_2.first} as #{_1}" }.join(", ")
              froms_sql = froms.join(" cross join ")
              wheres_sql = wheres.reduce { "#{_1} and #{_2}" }

              pending_activations << Rule::PendingActivation.new(
                selections.keys, [
                  "select distinct #{selections_sql}",
                  ("from #{froms_sql}" unless froms.empty?),
                  ("where #{wheres_sql}" unless wheres.empty?)
                ].compact.join(" ")
              )
            end
          end
        end

        if pending_activations.empty?
          # If we can't work out any relationship between the input
          # and the tables we need, then we have invalidate all
          # matches for this rule (which is expensive!)
          Set.new([ :all ])
        else
          pending_activations
        end
      end

      def bound_names
        constraints.map do |constraint|
          case constraint
          in RecordMatcher(_, clauses)
            clauses.map do |clause|
              case clause
              in BinaryOperatorExpression(Variable(left), "=", Variable(right))
                Set.new([ left, right ])
              in BinaryOperatorExpression(Variable(left), "=", _)
                Set.new([ left ])
              in BinaryOperatorExpression(_, "=", Variable(right))
                Set.new([ right ])
              else
                Set.new
              end
            end.reduce(&:+)
          in BinaryOperatorExpression(Variable(left), "=", Variable(right))
            Set.new([ left, right ])
          in BinaryOperatorExpression(Variable(left), "=", _)
            Set.new([ left ])
          in BinaryOperatorExpression(_, "=", Variable(right))
            Set.new([ right ])
          else
            Set.new
          end
        end.reduce(&:+)
      end

      def unparse = @constraints.map(&:unparse).join("\n")

      TableField = Struct.new(:table, :field, :field_name)

      private

      def populate_query_parts!
        return if @query_sql

        query_definer = QueryDefiner.new
        constraints.each do |constraint|
          case constraint
          in BinaryOperatorExpression(Variable(left), "=", Variable(right))
            query_definer.add_binding(left) { _1[right] }
            query_definer.add_binding(right) { _1[left] }
          in BinaryOperatorExpression(Variable(left), "=", right)
            query_definer.add_binding(left, &right.to_query(query_definer))
          in BinaryOperatorExpression(left, "=", Variable(right))
            query_definer.add_binding(right, &left.to_query(query_definer))
          else
            emitter = constraint.to_query(query_definer)
            query_definer.add_condition(&emitter) if emitter
          end
        end

        @table_names = query_definer.tables.keys.to_a
        @id_names, @other_names = query_definer.bindings.keys.partition { _1.start_with?("__id_") }
        @query_sql = <<~SQL.squish!
          select #{json_sql(@id_names)} as ids,
                 #{json_sql(@other_names)} as arguments
            from (
              #{query_definer.to_sql}
            ) as q
        SQL
      end

      def populate_table_edges!
        return if @graphs

        populate_query_parts!

        @graphs = Set.new
        @source_vertices = Hash.new { _1[_2] = [] }
        @sink_vertices = Set.new

        table_index = 0

        top_graph = Graph.new
        @graphs << top_graph
        top_bindings = Hash.new { _1[_2] = [] }
        to_do = constraints.map { [ _1, top_graph, top_bindings ] }

        while (constraint, graph, bindings = to_do.shift)
          case constraint
          in Aggregate(aggregated_constraints)
            subgraph = Graph.new(graph)
            @graphs << subgraph
            subbindings = bindings.deep_dup
            to_do += aggregated_constraints.map { [ _1, subgraph, subbindings ] }
          in Any(existential_constraints)
            subgraph = Graph.new(graph)
            @graphs << subgraph
            subbindings = bindings.deep_dup
            to_do += existential_constraints.map { [ _1, subgraph, subbindings ] }
          in Negation(negated_constraints)
            subgraph = Graph.new(graph)
            @graphs << subgraph
            subbindings = bindings.deep_dup
            to_do += negated_constraints.map { [ _1, subgraph, subbindings ] }
          in RecordMatcher(match_klass, clauses)
            table_alias = @table_names[table_index]
            if table_alias
              table_index += 1
            else
              table_alias = "#{match_klass.table_name}_#{table_index += 1}"
            end
            graph.add_vertex(table_alias, {
                               table_name: match_klass.table_name,
                               table_alias: table_alias
                             })

            @sink_vertices << table_alias if graph == top_graph
            @source_vertices[match_klass.table_name] << table_alias

            clauses.each do |clause|
              case clause
              in BinaryOperatorExpression(Variable(lhs), "=", RecordField(rhs))
                rhs_item = [ table_alias,
                             rhs,
                             match_klass.columns_hash[rhs].null ]
                bindings[lhs].each do |lhs_item|
                  lhs_alias, = lhs_item
                  graph.add_edge(table_alias, lhs_alias, [ lhs_item, rhs_item ])
                  graph.add_edge(lhs_alias, table_alias, [ rhs_item, lhs_item ])
                end
                bindings[lhs] << rhs_item
              in BinaryOperatorExpression(RecordField(lhs), "=", Variable(rhs))
                lhs_item = [ table_alias,
                             lhs,
                             match_klass.columns_hash[lhs].null ]
                bindings[rhs].each do |rhs_item|
                  rhs_alias, = rhs_item
                  graph.add_edge(table_alias, rhs_alias, [ lhs_item, rhs_item ])
                  graph.add_edge(rhs_alias, table_alias, [ rhs_item, lhs_item ])
                end
                bindings[rhs] << lhs_item
              else
                # Recurse into the LHS and RHS to find other relevant tables.
                to_do << clause
              end
            end
          in BinaryOperatorExpression(Variable(lhs), "=", Variable(rhs))
            bindings[lhs].each do |lhs_item|
              lhs_alias, = lhs_item
              bindings[rhs].each do |rhs_item|
                rhs_alias, = rhs_item
                graph.add_edge(lhs_alias, rhs_alias, [ lhs_item, rhs_item ])
                graph.add_edge(rhs_alias, lhs_alias, [ lhs_item, rhs_item ])
              end
            end
            bindings[lhs] = bindings[lhs] + bindings[rhs]
            bindings[rhs] = bindings[lhs]
          in BinaryOperatorExpression(lhs, _, rhs)
            # Recurse into the LHS and RHS to find other relevant tables.
            to_do << [ lhs, graph, bindings ]
            to_do << [ rhs, graph, bindings ]
          else
            # we're not handling anything else
            nil
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
