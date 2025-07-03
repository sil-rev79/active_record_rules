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
            "json_group_array(#{expr.call(bindings)} order by 1)"
          elsif ActiveRecordRules.dialect == :postgres
            "json_agg(#{expr.call(bindings)} order by 1)"
          else
            raise "Unknown dialect: #{ActiveRecordRules.dialect}"
          end
        end
      end

      def final_result(self_expression)
        QueryDefiner::SqlExpr.new(
          if ActiveRecordRules.dialect == :sqlite
            "jsonb(coalesce(#{self_expression}, json_array()))"
          elsif ActiveRecordRules.dialect == :postgres
            "coalesce(#{self_expression}, json_build_array())"
          else
            raise "Unknown dialect: #{ActiveRecordRules.dialect}"
          end,
          false
        )
      end

      def unparse
        "array(#{expression.unparse}) { #{@constraints.map(&:unparse).join("; ")} }"
      end
    end
  end
end
