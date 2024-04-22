# frozen_string_literal: true

module ActiveRecordRules
  module Ast
    class Node
      # Convert this node into a textual representation which can be
      # parsed again.
      def unparse = (raise NotImplementedError, "No unparse method defined on #{self.class}")
    end
  end
end
