# frozen_string_literal: true

require "active_record_rules/ast/expression_node"
require "active_record_rules/query_definer"

module ActiveRecordRules
  module Ast
    class Aggregate < ExpressionNode
      attr_reader :constraints

      def initialize(constraints)
        super()
        @constraints = (constraints || []).freeze
      end

      def to_query(definer)
        query_definer = QueryDefiner.new(definer)
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
        value_name = "__value#{definer.next_index}"
        query_definer.add_binding(value_name, &define_expression(query_definer))

        # I had intended for these to be left joins, but the queries
        # that get constructed might need to interact with the outside
        # query, so it would have to be a lateral join. These aren't
        # supported in SQLite at the moment, so doing this as a
        # subquery lets us keep better SQL engine compatibility.
        lambda do |bindings|
          (bindings.keys & query_definer.bindings.keys).each do |name|
            # This query_definer.bindings call is a bit of a cludge to
            # get a value that's valid in the subquery, rather than in
            # the parent query.
            query_definer.add_condition do
              QueryDefiner::SqlExpr.new(
                gen_eq(
                  bindings[name],
                  query_definer.bindings[name].map { _1.call(bindings) }.min_by(&:length)
                ),
                false
              )
            end
          end
          sql = query_definer.to_sql(bindings, [ value_name ]) # Then we only emit __value here

          # Wrap the result in parens, because it's a subquery
          final_result("(#{sql})")
        end
      end

      def relevant_change?(klass, previous, current)
        @constraints.any? { _1.relevant_change?(klass, previous, current) }
      end

      def record_relevant_attributes(tracker)
        @constraints.each { _1.record_relevant_attributes(tracker) }
      end

      def deconstruct = [ constraints ]
    end
  end
end
