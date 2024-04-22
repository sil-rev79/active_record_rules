# frozen_string_literal: true

require "active_record_rules/ast/aggregate"

module ActiveRecordRules
  module Ast
    class Count < Aggregate
      attr_reader :expression

      def initialize(expression, constraints)
        super(constraints)
        @expression = expression
      end

      def define_expression(query_definer)
        expr = @expression.to_query(query_definer) if @expression
        lambda do |bindings|
          if expr
            "count(distinct #{expr.call(bindings)})"
          else
            "count(1)"
          end
        end
      end

      def final_result(self_expression) = "coalesce(#{self_expression}, 0)"

      def unparse
        if expression
          "count(#{expression.unparse}) { #{@constraints.map(&:unparse).join("; ")} }"
        else
          "count { #{@constraints.map(&:unparse).join("; ")} }"
        end
      end
    end
  end
end
