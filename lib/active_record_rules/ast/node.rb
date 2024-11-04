# frozen_string_literal: true

module ActiveRecordRules
  module Ast
    class Node
      # Convert this node into a textual representation which can be
      # parsed again.
      def unparse = (raise NotImplementedError, "No unparse method defined on #{self.class}")

      private

      # SQL NULL doesn't play nice with Ruby-style NULL semantics, so
      # we have to generate a more complex expression here. In theory
      # we could use the IS NOT DISTINCT FROM operator in SQL, but in
      # practice it doesn't use indexes in Postgres, so it's no good.
      def gen_eq(left, right)
        case [left.to_s, right.to_s]
        in "NULL", "NULL"
          "TRUE"
        in "NULL", _
          "#{right} is NULL"
        in _, "NULL"
          "#{left} is NULL"
        else
          if left.nullable? && right.nullable?
            "(#{left.sql} = #{right.sql} or (#{left.sql} is null and #{right.sql} is null)) is true"
          elsif left.nullable? || right.nullable?
            "(#{left.sql} = #{right.sql}) is true"
          else
            "(#{left.sql} = #{right.sql})"
          end
        end
      end
    end
  end
end
