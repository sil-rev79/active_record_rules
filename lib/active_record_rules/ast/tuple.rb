# frozen_string_literal: true

require "active_record_rules/ast/expression_node"

module ActiveRecordRules
  module Ast
    class Tuple < ExpressionNode
      attr_reader :name

      def initialize(elements)
        super()
        @elements = elements
      end

      def id_paths(vars)
        @elements.each_with_index.map do |element, i|
          id_paths = element.id_paths(vars)
          next if id_paths.empty?

          id_paths.transform_keys { [ i ] + _1 }
        end.compact.reduce({}, &:merge)
      end

      def to_query(definer)
        procs = @elements.map { _1.to_query(definer) }
        lambda do |bindings|
          values = procs.map { _1.call(bindings) }
          QueryDefiner::SqlExpr.new(
            if ActiveRecordRules.dialect == :sqlite
              "jsonb_array(#{values.join(", ")})"
            elsif ActiveRecordRules.dialect == :postgres
              "jsonb_build_array(#{values.join(", ")})"
            else
              raise "Unknown dialect: #{ActiveRecordRules.dialect}"
            end,
            false
          )
        end
      end

      def relevant_change?(klass, previous, current)
        @elements.any? { _1.relevant_change?(klass, previous, current) }
      end

      def deconstruct = [ @elements ]

      def unparse = "[#{@elements.map(&:unparse).join(", ")}]"
    end
  end
end
