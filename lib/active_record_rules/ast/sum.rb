# frozen_string_literal: true

require "active_record_rules/ast/aggregate"

module ActiveRecordRules
  module Ast
    class Sum < Aggregate
      attr_reader :expression

      def initialize(expression, constraints)
        super(constraints)
        @expression = expression
      end

      def id_paths(_) = {}

      def define_expression(query_definer)
        expr = @expression.to_query(query_definer)
        ->(bindings) { "sum(#{expr.call(bindings)})" }
      end

      def final_result(self_expression) = QueryDefiner::SqlExpr.new("coalesce(#{self_expression}, 0)", false)

      def unparse
        "sum(#{expression.unparse}) { #{@constraints.map { "\n" + _1.unparse }.indent(2)} }"
      end
    end
  end
end
