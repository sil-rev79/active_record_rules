# frozen_string_literal: true

require "active_record_rules/ast/expression_node"
require "active_record_rules/ast/variable"
require "active_record_rules/query_definer"

module ActiveRecordRules
  module Ast
    class Any < ExpressionNode
      attr_reader :constraints

      def initialize(constraints)
        super()
        @constraints = (constraints || []).freeze
      end

      def to_query(definer)
        query_definer = QueryDefiner.new(definer)
        constraints.each do |constraint|
          emitter = constraint.to_query(query_definer)
          query_definer.add_condition(&emitter) if emitter
        end.compact
        query_definer.add_binding("__value") { "1" }

        lambda do |bindings|
          sql = query_definer.to_sql(bindings, ["__value"])
          QueryDefiner::SqlExpr.new("exists (#{sql.split("\n").join("\n        ")})", false)
        end
      end

      def record_relevant_attributes(tracker)
        @constraints.each { _1.record_relevant_attributes(tracker) }
      end

      def relevant_change?(klass, previous, current)
        @constraints.any? { _1.relevant_change?(klass, previous, current) }
      end

      def unparse = "any { #{@constraints.map(&:unparse).join("; ")} }"
      def deconstruct = [constraints]
    end
  end
end
