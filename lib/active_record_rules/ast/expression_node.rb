# frozen_string_literal: true

require "active_record_rules/ast/node"

module ActiveRecordRules
  module Ast
    class ExpressionNode < Node
      def to_query(_) = (raise NotImplementedError, "No to_query method defined on #{self.class}")
      def record_relevant_attributes(_) = nil
    end
  end
end
