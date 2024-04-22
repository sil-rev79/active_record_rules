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
        query_definer = QueryDefiner.new
        constraints.each do |constraint|
          emitter = constraint.to_query(query_definer)
          query_definer.add_condition(&emitter) if emitter
        end
        query_definer.add_binding("__value", &define_expression(query_definer))

        on_condition = lambda do |table_name, bindings|
          (bindings.keys & query_definer.bindings.keys).map do |name|
            next if name == "__value" # ignore our special value

            "(#{table_name}.#{name} = #{bindings[name]})"
          end.compact.join("\n   and ")
        end
        table_definer = definer.define_table("aggregate", on_condition) do |bindings|
          sql = query_definer.to_sql(bindings, bindings.keys + ["__value"])
          # We convert the names into numbers (starting from 1),
          # which matches SQL's requirements. This assumes the
          # __value key is always placed last.
          group_by = (bindings.keys & query_definer.bindings.keys).each_with_index.map { _2 + 1 }.join(", ")
          if group_by.empty?
            "(#{sql})"
          else
            "(#{sql}\n group by #{group_by})"
          end
        end

        ->(_) { final_result("#{table_definer.table_name}.__value") }
      end

      def bound_names = Set.new
    end
  end
end
