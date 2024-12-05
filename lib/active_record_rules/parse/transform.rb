# frozen_string_literal: true

require "parslet"
require "active_record_rules/ast"

module ActiveRecordRules
  module Parse
    class Transform < Parslet::Transform # :nodoc:
      include ::ActiveRecordRules::Ast

      JsonExtraction = Struct.new(:path, :type)

      rule(integer: simple(:value)) { Constant.new(value.to_i) }
      rule(number: simple(:value)) { Constant.new(value.to_f) }
      rule(string: simple(:value)) { Constant.new(value.to_s) }
      rule(boolean: simple(:value)) { Constant.new(value.to_s == "true") }
      rule(nil: simple(:value)) { Constant.new(nil) }
      rule(binding_name: simple(:value)) { Variable.new(value.to_s) }
      rule(tuple_elements: sequence(:tuple_elements)) { Tuple.new(tuple_elements) }
      rule(record_name: simple(:value)) do
        RecordField.new(value.line_and_column, *value.to_s.split(":"))
      end
      rule(record_name: simple(:value), json_extraction: simple(:json_extraction)) do
        JsonLookup.new(
          RecordField.new(value.line_and_column, *value.to_s.split(":")),
          json_extraction.path,
          json_extraction.type
        )
      end

      rule(json_field_name: simple(:json_field_name)) { Constant.new(json_field_name.to_s) }
      rule(json_path: sequence(:json_path), type: simple(:type)) { JsonExtraction.new(json_path, type.to_s) }

      rule(aggregate_operation: simple(:name), constraints: sequence(:constraints)) do
        class_name = name.to_s.split("_").map(&:capitalize).join
        Object.const_get("ActiveRecordRules::Ast::#{class_name}").new(nil, constraints)
      end
      rule(aggregate_operation: simple(:name), expression: simple(:expression), constraints: sequence(:constraints)) do
        class_name = name.to_s.split("_").map(&:capitalize).join
        Object.const_get("ActiveRecordRules::Ast::#{class_name}").new(expression, constraints)
      end

      rule(operation: "any", constraints: sequence(:constraints)) do
        Any.new(constraints)
      end
      rule(operation: "not", constraints: sequence(:constraints)) do
        Negation.new(constraints)
      end

      rule(simple_name_clause: simple(:name)) do
        raw_name, flags = name.to_s.split(":")
        BinaryOperatorExpression.new(
          RecordField.new(name.line_and_column, raw_name, flags),
          "=",
          Variable.new(raw_name)
        )
      end

      rule(lhs: simple(:left), op: simple(:op), rhs: simple(:right)) do
        BinaryOperatorExpression.new(left, op.to_s, right)
      end

      rule(class_name: simple(:class_name), boolean_clauses: subtree(:clauses)) do
        RecordMatcher.new(class_name.to_s, clauses || [])
      end

      rule(constraints: sequence(:constraints)) do
        ConstraintSet.new(constraints)
      end

      rule(line: simple(:line)) do
        line
      end

      rule(
        timing: simple(:timing),
        name: simple(:name),
        constraints: sequence(:constraints),
        on_match: subtree(:on_match),
        on_update: subtree(:on_update),
        on_unmatch: subtree(:on_unmatch)
      ) do
        Definition.new(
          timing.line_and_column,
          timing.to_s,
          name.to_s.strip,
          constraints,
          on_match&.join("\n"),
          on_update&.join("\n"),
          on_unmatch&.join("\n")
        )
      end
    end
  end
end
