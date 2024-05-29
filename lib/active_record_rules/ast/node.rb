# frozen_string_literal: true

module ActiveRecordRules
  module Ast
    class Node
      # Convert this node into a textual representation which can be
      # parsed again.
      def unparse = (raise NotImplementedError, "No unparse method defined on #{self.class}")

      private

      def gen_eq(left, right)
        case [left, right]
        in "NULL", "NULL"
          "TRUE"
        in "NULL", _
          "#{right} is NULL"
        in _, "NULL"
          "#{left} is NULL"
        else
          "(#{left} = #{right} or (#{left} is null and #{right} is null))"
        end
      end
    end
  end
end
