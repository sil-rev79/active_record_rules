# frozen_string_literal: true

require "active_record_rules/ast/aggregate"

module ActiveRecordRules
  module Ast
    class Array < Aggregate
      attr_reader :expression

      def initialize(expression, constraints)
        super(constraints)
        @expression = expression
      end

      def define_expression(query_definer)
        expr = @expression.to_query(query_definer)
        lambda do |bindings|
          if ActiveRecordRules.dialect == :sqlite
            raise "The `array' aggregate is not available for SQLite"
          elsif ActiveRecordRules.dialect == :postgres
            "array_agg(#{expr.call(bindings)})"
          else
            raise "Unknown dialect: #{ActiveRecordRules.dialect}"
          end
        end
      end

      def final_result(self_expression)
        QueryDefiner::SqlExpr.new("coalesce(#{self_expression}, '{}')", false)
      end

      def unparse
        "array(#{expression.unparse}) { #{@constraints.map(&:unparse).join("; ")} }"
      end
    end
  end
end
