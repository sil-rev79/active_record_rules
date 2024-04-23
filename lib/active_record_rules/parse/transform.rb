# frozen_string_literal: true

require "parslet"
require "active_record_rules/ast"

module ActiveRecordRules
  module Parse
    class Transform < Parslet::Transform # :nodoc:
      include ::ActiveRecordRules::Ast

      rule(integer: simple(:value)) { Constant.new(value.to_i) }
      rule(number: simple(:value)) { Constant.new(value.to_f) }
      rule(string: simple(:value)) { Constant.new(value.to_s) }
      rule(boolean: simple(:value)) { Constant.new(value.to_s == "true") }
      rule(nil: simple(:value)) { Constant.new(nil) }
      rule(binding_name: simple(:value)) { Variable.new(value.to_s) }
      rule(record_name: simple(:value)) { RecordField.new(value.to_s) }
      rule(operation: "count", constraints: sequence(:constraints)) do
        Count.new(nil, constraints)
      end
      rule(operation: "count", expression: simple(:expression), constraints: sequence(:constraints)) do
        Count.new(expression, constraints)
      end
      rule(operation: "sum", expression: simple(:expression), constraints: sequence(:constraints)) do
        Sum.new(expression, constraints)
      end
      rule(operation: "array", expression: simple(:expression), constraints: sequence(:constraints)) do
        ::ActiveRecordRules::Ast::Array.new(expression, constraints)
      end
      rule(operation: "not", constraints: sequence(:constraints)) do
        Negation.new(constraints)
      end

      rule(simple_name_clause: simple(:name)) do
        Comparison.new(
          RecordField.new(name.to_s),
          "=",
          Variable.new(name.to_s)
        )
      end

      rule(lhs: simple(:left), comparison: simple(:comparison), rhs: simple(:right)) do
        Comparison.new(left, comparison.to_s, right)
      end

      rule(lhs: simple(:left), op: simple(:op), rhs: simple(:right)) do
        BinaryOperatorExpression.new(left, op.to_s, right)
      end

      rule(class_name: simple(:class_name), boolean_clauses: subtree(:clauses)) do
        RecordMatcher.new(class_name.to_s, clauses || [])
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
        Definition.new(
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
