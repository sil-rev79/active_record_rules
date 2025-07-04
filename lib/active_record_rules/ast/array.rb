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

      def id_paths(vars)
        @expression.id_paths(
          vars.merge(
            ConstraintSet.new(@constraints).extract_id_variables
          )
        ).transform_keys { [ :all ] + _1 }
      end

      def define_expression(query_definer)
        expr = @expression.to_query(query_definer)
        lambda do |bindings|
          expr_str = expr.call(bindings)
          if ActiveRecordRules.dialect == :sqlite
            "json_group_array(#{expr_str} order by #{expr_str})"
          elsif ActiveRecordRules.dialect == :postgres
            "json_agg(#{expr_str} order by #{expr_str})"
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
        "array(#{expression.unparse}) {#{@constraints.map { "\n" + _1.unparse }.join.indent(2)}\n}"
      end
    end
  end
end
