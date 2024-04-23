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
        # Negations all get emitted as subqueries within a "not
        # exists" clause.
        #
        # I'd prefer to use a "left join" with a null-check, but it's
        # more complicated to construct the right queries. Hopefully
        # the database can optimise the subquery well enough. 😬

        query_definer = QueryDefiner.new(definer)
        constraints.each do |constraint|
          emitter = constraint.to_query(query_definer)
          query_definer.add_condition(&emitter) if emitter
        end.compact
        query_definer.add_binding("__value") { "1" }

        lambda do |bindings|
          sql = query_definer.to_sql(bindings, ["__value"])
          "not exists (#{sql.split("\n").join("\n            ")})"
        end
      end

      def bound_names = Set.new
      def unparse = "not { #{@constraints.map(&:unparse).join("; ")} }"
    end
  end
end
