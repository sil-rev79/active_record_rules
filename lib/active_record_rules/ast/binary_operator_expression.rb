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
        operator = case @operator
                   in "="
                     "is not distinct from"
                   in "!="
                     "is distinct from"
                   else
                     @operator
                   end

        left = @lhs.to_query(definer)
        right = @rhs.to_query(definer)
        lambda do |bindings|
          left_str = left.call(bindings)
          right_str = right.call(bindings)
          "(#{left_str} #{operator} #{right_str})"
        end
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

      def deconstruct = [@lhs, @operator, @rhs]
    end
  end
end
