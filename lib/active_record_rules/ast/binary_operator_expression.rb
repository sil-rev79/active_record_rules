# frozen_string_literal: true

require "active_record_rules/ast/expression_node"

module ActiveRecordRules
  module Ast
    class BinaryOperatorExpression < ExpressionNode
      attr_reader :lhs, :operator, :rhs

      def initialize(lhs, operator, rhs)
        super()
        @lhs = lhs
        @operator = operator
        @rhs = rhs
      end

      def to_query(definer)
        left = @lhs.to_query(definer)
        right = @rhs.to_query(definer)
        ->(bindings) { "(#{left.call(bindings)} #{@operator} #{right.call(bindings)})" }
      end

      def relevant_change?(klass, previous, current)
        @lhs.relevant_change?(klass, previous, current) ||
          @rhs.relevant_change?(klass, previous, current)
      end

      def record_relevant_attributes(tracker)
        @lhs.record_relevant_attributes(tracker)
        @rhs.record_relevant_attributes(tracker)
      end

      def unparse = "#{@lhs.unparse} #{@operator} #{@rhs.unparse}"
    end
  end
end
