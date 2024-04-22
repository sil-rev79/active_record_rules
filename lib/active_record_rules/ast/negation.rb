# frozen_string_literal: true

require "active_record_rules/ast/expression_node"
require "active_record_rules/ast/variable"
require "active_record_rules/query_definer"

module ActiveRecordRules
  module Ast
    class Negation < ExpressionNode
      attr_reader :constraints

      def initialize(constraints)
        super()
        @constraints = (constraints || []).freeze
      end

      def to_query(definer)
        # We have a problem here.
        #
        # We need to lift conditions like `racers_2.race_time < racers_1.race_time` up, into the
        # `on` part of the query. However, the bit that emits that comes from within the RecordMatch
        # node, which doesn't reveal that internal structure this high.
        #
        # We can detect the cases which need to be lifted, because they reference variables that are
        # not bound in the subquery. However, we don't know that until we get to the point of
        # emitting, at which point we don't have a pathway for the value to come back up (yet).
        #
        # Maybe a richer representation for emitters would be helpful here. One that would allow us
        # to move them around, and do some table renaming. Or maybe we should just make a proper SQL
        # AST (or use Arel?).

        query_definer = QueryDefiner.new(definer)
        constraints.each do |constraint|
          emitter = constraint.to_query(query_definer)
          query_definer.add_condition(&emitter) if emitter
        end.compact
        query_definer.add_binding("__value") { "1" }

        on_condition = lambda do |table_name, bindings|
          (bindings.keys & query_definer.bindings.keys).map do |name|
            next if name == "__value" # ignore our special value

            "(#{bindings[name]} = #{table_name}.#{name})"
          end.compact.join("\n   and ")
        end
        table_definer = definer.define_table("negation", on_condition) do |bindings|
          sql = query_definer.to_sql(bindings, bindings.keys + ["__value"])
          "(#{sql})"
        end
        ->(_) { "#{table_definer.table_name}.__value is null" }
      end

      def bound_names = Set.new
      def unparse = "not { #{@constraints.map(&:unparse).join("; ")} }"
    end
  end
end
