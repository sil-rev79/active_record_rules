# frozen_string_literal: true

require "active_record_rules/ast/expression_node"

module ActiveRecordRules
  module Ast
    class RecordField < ExpressionNode
      attr_reader :name

      def initialize(name)
        super()
        @name = name
      end

      def to_query(definer) = ->(_) { "#{definer.table_name}.#{@name}" }

      def relevant_change?(_, previous, current)
        previous[@name] != current[@name]
      end

      def record_relevant_attributes(tracker)
        tracker.add(@name)
      end

      def deconstruct = [@name]

      def unparse = @name
    end
  end
end
