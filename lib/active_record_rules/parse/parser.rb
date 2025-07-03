# frozen_string_literal: true

require "parslet"

module ActiveRecordRules
  module Parse
    class Parser < Parslet::Parser # :nodoc:
      rule(:constraints) do
        (
          whitespace.maybe >> (record_matcher | boolean_expression)
        ).repeat.as(:constraints) >> whitespace.maybe
      end

      rule(:inline_constraints) do
        (record_matcher | boolean_expression).repeat(1, 1) >>
          (whitespace.maybe >> (record_matcher | boolean_expression)).repeat
      end

      rule(:record_matcher) do
        class_name.as(:class_name) >>
          whitespace.maybe >>
          str("(") >>
          separated(boolean_clause).maybe.as(:boolean_clauses) >>
          str(")")
      end

      rule(:boolean_clause) do
        boolean_expression | (
          str("<") >> record_name.as(:simple_name_clause) >> str(">")
        )
      end

      rule(:boolean_expression) do
        infix_expression(
          (str("(") >> boolean_expression >> str(")")) |
          (
            (
              str("not") | str("any")
            ).as(:operation) >> whitespace.maybe >>
            str("{") >> whitespace.maybe >>
            inline_constraints.as(:constraints) >> whitespace.maybe >>
            str("}")
          ) |
          (
            expression.as(:lhs) >> whitespace.maybe >>
            comparison.as(:op) >> whitespace.maybe >>
            expression.as(:rhs)
          ),
          [whitespace.maybe >> str("or").as(:op) >> whitespace.maybe, 1, :left],
          [whitespace.maybe >> str("and").as(:op) >> whitespace.maybe, 2, :left]
        ) { |l, o, r| { lhs: l, op: o[:op], rhs: r } }
      end

      rule(:comparison) do
        (str("=") |
         str("!=") |
         str("<=") |
         str("<") |
         str(">=") |
         str(">") |
         str("in") |
         (str("not") >> whitespace >> str("in")))
      end

      # ===========
      # Expressions
      # ===========

      def separated(rule, sep: str(","), whitespace: self.whitespace)
        whitespace.maybe >> rule.repeat(1, 1) >>
          (whitespace.maybe >> sep >> whitespace.maybe >> rule).repeat >>
          whitespace.maybe
      end

      rule(:expression) do
        infix_expression(
          (
            # Recursive case
            (str("(") >> expression >> str(")")) |
            # Variable bindings wrapped in < >
            (str("<") >> name.as(:binding_name) >> str(">")) |
            # Tuples wrapped in [ ]
            (str("[") >> separated(expression).as(:tuple_elements) >> str("]")) |
            # Aggregate operators
            aggregate |
            # Primitives
            boolean |
            string |
            number |
            integer |
            nil_expr |
            # Database fields
            record_expression
          ),
          [whitespace.maybe >> match("[+-]").as(:op) >> whitespace.maybe, 1, :left],
          [whitespace.maybe >> match("[*/]").as(:op) >> whitespace.maybe, 2, :left]
        ) { |l, o, r| { lhs: l, op: o[:op], rhs: r } }
      end

      rule(:record_expression) do
        record_name.as(:record_name)
      end

      rule(:string) do
        str('"') >>
          (
            (str("\\") >> any) |
            (str('"').absent? >> any)
          ).repeat.as(:string) >>
          str('"')
      end

      rule(:integer) do
        (
          match("[+-]").maybe >>
          match("[0-9]").repeat(1)
        ).as(:integer)
      end

      rule(:number) do
        (
          match("[+-]").maybe >>
          match("[0-9]").repeat(1) >>
          str(".") >>
          match("[0-9]").repeat
        ).as(:number)
      end

      rule(:boolean) do
        (str("true") | str("false")).as(:boolean) >> match("[a-zA-Z0-9]_!?").absent?
      end

      rule(:nil_expr) do
        str("nil").as(:nil) >> match("[a-zA-Z0-9]_!?").absent?
      end

      def aggregate_op(name, require_expression: true)
        expr_part = (
          str("(") >> whitespace.maybe >>
          expression.as(:expression) >> whitespace.maybe >>
          str(")")
        )
        str(name).as(:aggregate_operation) >> whitespace.maybe >>
          (require_expression ? expr_part : expr_part.maybe) >> whitespace.maybe >>
          str("{") >> whitespace.maybe >>
          inline_constraints.as(:constraints) >> whitespace.maybe >>
          str("}")
      end

      rule(:aggregate) do
        aggregate_op("count", require_expression: false) |
          aggregate_op("sum") |
          aggregate_op("maximum") |
          aggregate_op("minimum") |
          aggregate_op("array")
      end

      # ================
      # Simple terminals
      # ================

      rule(:name) do
        (match("[a-zA-Z_]") >> match("[a-zA-Z_0-9!?]").repeat)
      end

      rule(:record_name) do
        (match("[a-zA-Z_]") >> match("[a-zA-Z_0-9!?]").repeat) >>
          (str(":") >> match("[is]")).maybe # enum specification
      end

      rule(:class_name) do
        (name >> (str("::") >> name).repeat)
      end

      rule(:sql_type) do
        match("[A-Za-z]").repeat >> str("[]").maybe
      end

      # space or tab, or a "newline"
      rule(:whitespace) { (match("[ \t]") | newline).repeat(1) }

      rule(:eol) do
        str("\r\n") | str("\n") | str(";") # treat semicolons like newlines!
      end

      rule(:eof) do
        any.absent?
      end

      rule(:newline) do
        (str("#") >> (eol.absent? >> any).repeat).maybe >> eol
      end
    end
  end
end
