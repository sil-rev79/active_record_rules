# frozen_string_literal: true

require "active_record_rules/ast/expression_node"
require "active_record_rules/ast/variable"
require "active_record_rules/query_definer"

module ActiveRecordRules
  module Ast
    class Any < ExpressionNode
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
        end.compact
        value_name = "__value#{definer.next_index}"
        query_definer.add_binding(value_name) { "1" }

        lambda do |bindings|
          sql = query_definer.to_sql(bindings, [value_name])
          QueryDefiner::SqlExpr.new("exists (#{sql.split("\n").join("\n        ")})", false)
        end
      end

      def record_relevant_attributes(tracker)
        @constraints.each { _1.record_relevant_attributes(tracker) }
      end

      def relevant_change?(klass, previous, current)
        @constraints.any? { _1.relevant_change?(klass, previous, current) }
      end

      def unparse = "any { #{@constraints.map(&:unparse).join("; ")} }"
      def deconstruct = [constraints]
    end
  end
end
