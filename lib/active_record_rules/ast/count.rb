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
            "count(distinct #{expr.call(bindings).sql})"
          else
            "count(1)"
          end
        end
      end

      def id_paths(_) = {}

      def relevant_change?(klass, previous, current)
        @constraints.any? { _1.relevant_change?(klass, previous, current) }
      end

      def final_result(self_expression) = QueryDefiner::SqlExpr.new("coalesce(#{self_expression}, 0)", false)

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
