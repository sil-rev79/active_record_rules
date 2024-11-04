# frozen_string_literal: true

require "active_record_rules/ast/expression_node"
require "active_record_rules/query_definer"

module ActiveRecordRules
  module Ast
    class Aggregate < ExpressionNode
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
        end
        query_definer.add_binding("__value", &define_expression(query_definer))

        # I had intended for these to be left joins, but the queries
        # that get constructed might need to interact with the outside
        # query, so it would have to be a lateral join. These aren't
        # supported in SQLite at the moment, so doing this as a
        # subquery lets us keep better SQL engine compatibility.
        lambda do |bindings|
          (bindings.keys & query_definer.bindings.keys).each do |name|
            # This query_definer.bindings call is a bit of a cludge to
            # get a value that's valid in the subquery, rather than in
            # the parent query.
            query_definer.add_condition do
              QueryDefiner::SqlExpr.new(
                gen_eq(bindings[name], query_definer.bindings[name].first.call(bindings)),
                false
              )
            end
          end
          sql = query_definer.to_sql(bindings, ["__value"]) # Then we only emit __value here

          # We order by __value here to make the array aggregate
          # deterministic. It shouldn't really affect anything else.
          final_result("(#{sql}\n order by __value)")
        end
      end

      def relevant_change?(klass, previous, current)
        @constraints.any? { _1.relevant_change?(klass, previous, current) }
      end

      def record_relevant_attributes(tracker)
        @constraints.each { _1.record_relevant_attributes(tracker) }
      end

      def deconstruct = [constraints]
    end
  end
end
