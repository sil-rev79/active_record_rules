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

      def id_paths(existing) = @rhs.id_paths(@lhs.id_paths(existing))

      def to_query(definer)
        left = @lhs.to_query(definer)
        right = @rhs.to_query(definer)
        lambda do |bindings|
          left_str = left.call(bindings)
          right_str = right.call(bindings)

          case @operator
          in "="
            QueryDefiner::SqlExpr.new(gen_eq(left_str, right_str), false)
          in "!="
            QueryDefiner::SqlExpr.new("not (#{gen_eq(left_str, right_str)})", false)
          in "in"
            case ActiveRecordRules.dialect
            in :postgres
              QueryDefiner::SqlExpr.new("jsonb_build_array(#{left_str}) <@ #{right_str}",
                                        left_str.nullable? || right_str.nullable?)
            in :sqlite
              QueryDefiner::SqlExpr.new(
                "exists (select 1 from json_each(#{right_str}) where json_each.value = #{left_str})",
                false
              )
            end
          in /^not[ \t\n]+in$/
            case ActiveRecordRules.dialect
            in :postgres
              QueryDefiner::SqlExpr.new("not (jsonb_build_array(#{left_str}) <@ #{right_str})",
                                        left_str.nullable? || right_str.nullable?)
            in :sqlite
              QueryDefiner::SqlExpr.new(
                "not exists (select 1 from json_each(#{right_str}) where json_each.value = #{left_str})",
                false
              )
            end
          else
            QueryDefiner::SqlExpr.new(
              "(#{left_str.sql} #{@operator} #{right_str.sql})",
              left_str.nullable? || right_str.nullable?
            )
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

      def deconstruct = [ @lhs, @operator, @rhs ]
    end
  end
end
