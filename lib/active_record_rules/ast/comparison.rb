# frozen_string_literal: true

require "active_record_rules/ast/expression_node"
require "active_record_rules/ast/variable"

module ActiveRecordRules
  module Ast
    class Comparison < ExpressionNode
      attr_reader :lhs, :comparison, :rhs

      def initialize(lhs, comparison, rhs)
        super()
        @lhs = lhs
        @comparison = comparison
        @rhs = rhs
      end

      def to_query(definer)
        left = @lhs.to_query(definer)
        right = @rhs.to_query(definer)
        if @comparison == "="
          definer.add_binding(@lhs.name, &right) if @lhs.is_a?(Variable)
          definer.add_binding(@rhs.name, &left) if @rhs.is_a?(Variable)
          return if @lhs.is_a?(Variable) || @rhs.is_a?(Variable)
        end

        lambda do |bindings|
          left_str = left.call(bindings)
          right_str = right.call(bindings)
          comparison =
            case [left_str, @comparison, right_str]
            in ["NULL", "=", _] | [_, "=", "NULL"]
              "is"
            in ["NULL", "!=", _] | [_, "!=", "NULL"]
              "is not"
            else
              @comparison
            end
          "(#{left_str} #{comparison} #{right_str})"
        end
      end

      def bound_names
        @bound_names ||= if @comparison == "="
                           [
                             (@lhs.name if @lhs.is_a?(Variable)),
                             (@rhs.name if @rhs.is_a?(Variable))
                           ].compact.to_set
                         else
                           Set.new
                         end
      end

      def relevant_change?(klass, previous, current)
        @lhs.relevant_change?(klass, previous, current) ||
          @rhs.relevant_change?(klass, previous, current)
      end

      # Return the names of variables that are bound to this record's id
      def id_bindings = Set.new

      def unparse = "#{@lhs.unparse} #{@comparison} #{@rhs.unparse}"

      def deconstruct = [@lhs, @comparison, @rhs]
    end
  end
end
