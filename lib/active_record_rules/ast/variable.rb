# frozen_string_literal: true

require "active_record_rules/ast/expression_node"

module ActiveRecordRules
  module Ast
    class Variable < ExpressionNode
      attr_reader :name

      def initialize(name)
        super()
        @name = name
      end

      def id_paths(vars)
        vars.select { _1[0] == @name }.transform_keys { _1[1..] }
      end

      def relevant_change?(_, _, _) = false
      def deconstruct = [ @name ]
      def to_query(_) = ->(bindings) { bindings[@name] }
      def unparse = "<#{@name}>"
    end
  end
end
