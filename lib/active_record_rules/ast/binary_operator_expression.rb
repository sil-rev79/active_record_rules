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
        lambda do |bindings|
          left_str = left.call(bindings)
          right_str = right.call(bindings)

          case @operator
          in "="
            gen_eq(left_str, right_str)
          in "!="
            "not #{gen_eq(left_str, right_str)}"
          in "in"
            case ActiveRecordRules.dialect
            in :postgres
              "array[#{left_str}] <@ #{right_str}"
            in :sqlite
              "exists (select 1 from json_each(#{right_str}) where json_each.value = #{left_str})"
            end
          else
            "(#{left_str} #{@operator} #{right_str})"
          end
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
