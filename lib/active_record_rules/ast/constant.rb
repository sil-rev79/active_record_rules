# frozen_string_literal: true

require "active_record_rules/ast/expression_node"

module ActiveRecordRules
  module Ast
    class Constant < ExpressionNode
      attr_reader :value

      def initialize(value)
        super()
        @value = value
      end

      def relevant_change?(_, _, _) = false
      def to_query(_) = ->(_) { ActiveRecord::Base.connection.quote(@value) }
      def unparse = @value.nil? ? "nil" : JSON.dump(@value)
    end
  end
end
