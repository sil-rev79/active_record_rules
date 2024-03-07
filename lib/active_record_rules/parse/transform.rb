# frozen_string_literal: true

require "parslet"

module ActiveRecordRules
  module Parse
    class Transform < Parslet::Transform # :nodoc:
      rule(integer: simple(:value)) { Ast::Constant.new(value.to_i) }
      rule(number: simple(:value)) { Ast::Constant.new(value.to_f) }
      rule(string: simple(:value)) { Ast::Constant.new(value.to_s) }
      rule(boolean: simple(:value)) { Ast::Constant.new(value.to_s == "true") }
      rule(nil: simple(:value)) { Ast::Constant.new(nil) }
      rule(binding_name: simple(:value)) { Ast::Variable.new(value.to_s) }
      rule(record_name: simple(:value)) { Ast::RecordField.new(value.to_s) }

      rule(simple_name_clause: simple(:name)) do
        Ast::Comparison.new(
          Ast::RecordField.new(name.to_s),
          "=",
          Ast::Variable.new(name.to_s)
        )
      end

      rule(lhs: simple(:left), comparison: simple(:comparison), rhs: simple(:right)) do
        Ast::Comparison.new(left, comparison.to_s, right)
      end

      rule(lhs: simple(:left), op: simple(:op), rhs: simple(:right)) do
        Ast::BinaryOperatorExpression.new(left, op.to_s, right)
      end

      rule(negated: simple(:negated), class_name: simple(:class_name), boolean_clauses: subtree(:clauses)) do
        Ast::RecordMatcher.new(!negated.nil?, class_name.to_s, clauses || [])
      end

      rule(line: simple(:line)) do
        line
      end

      rule(
        name: simple(:name),
        constraints: sequence(:constraints),
        on_match: subtree(:on_match),
        on_update: subtree(:on_update),
        on_unmatch: subtree(:on_unmatch)
      ) do
        Ast::Definition.new(
          name.to_s,
          constraints,
          on_match&.join("\n"),
          on_update&.join("\n"),
          on_unmatch&.join("\n")
        )
      end
    end
  end
end
