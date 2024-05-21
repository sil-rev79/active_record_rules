# frozen_string_literal: true

require "active_record_rules/ast/aggregate"

module ActiveRecordRules
  module Ast
    class Maximum < Aggregate
      attr_reader :expression

      def initialize(expression, constraints)
        super(constraints)
        @expression = expression
      end

      def define_expression(query_definer)
        expr = @expression.to_query(query_definer)
        lambda do |bindings|
          "max(#{expr.call(bindings)})"
        end
      end

      def final_result(self_expression)
        self_expression
      end

      def unparse
        "maximum(#{expression.unparse}) { #{@constraints.map(&:unparse).join("; ")} }"
      end
    end
  end
end
