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
          if never_null?(left) && never_null?(right)
            "(#{left} = #{right})"
          elsif never_null?(left) || never_null?(right)
            "(#{left} = #{right}) is true"
          else
            "(#{left} = #{right} or (#{left} is null and #{right} is null)) is true"
          end
        end
      end

      def never_null?(value)
        value = value.downcase
        # If the value starts with one of these characters then it's a constant, and thus not null.
        "0123456789'".include?(value.first) ||
          # Constant true/false is not null
          value == "true" ||
          value == "false" ||
          # This is hacky: we're assuming that "id" fields are never
          # null. Ideally this would be based on actually knowing the
          # database structure so this can work for other fields, too,
          # but that's too hard right now and this is necessary to get
          # Postgres to use primary key indexes.
          value.end_with?(".id")
      end
    end
  end
end
