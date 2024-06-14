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
        case [left, right]
        in "NULL", "NULL"
          "TRUE"
        in "NULL", _
          "#{right} is NULL"
        in _, "NULL"
          "#{left} is NULL"
        else
          "(#{left} = #{right} or (#{left} is null and #{right} is null)) is true"
        end
      end
    end
  end
end
