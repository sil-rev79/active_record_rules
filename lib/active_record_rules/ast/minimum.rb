# frozen_string_literal: true

require "active_record_rules/ast/aggregate"

module ActiveRecordRules
  module Ast
    class Minimum < Aggregate
      attr_reader :expression

      def initialize(expression, constraints)
        super(constraints)
        @expression = expression
      end

      def define_expression(query_definer)
        expr = @expression.to_query(query_definer)
        lambda do |bindings|
          "min(#{expr.call(bindings)})"
        end
      end

      def final_result(self_expression)
        QueryDefiner::SqlExpr.new(self_expression, true)
      end

      def unparse
        "minimum(#{expression.unparse}) { #{@constraints.map(&:unparse).join("; ")} }"
      end
    end
  end
end
