# frozen_string_literal: true

require "parslet"

module ActiveRecordRules
  module Parse
    class Parser < Parslet::Parser # :nodoc:
      rule(:definitions) do
        ((whitespace | newline).repeat >> definition).repeat >> (whitespace | newline).repeat
      end

      rule(:definition) do
        str("rule") >> whitespace >>
          (newline.absent? >> any).repeat.as(:name) >> newline >>
          constraints.as(:constraints) >>
          on_match.maybe.as(:on_match) >>
          on_update.maybe.as(:on_update) >>
          on_unmatch.maybe.as(:on_unmatch)
      end

      # =============
      # Rule elements
      # =============

      rule(:constraints) do
        (
          (whitespace.maybe >> newline).repeat >> (
            # This is a line with content:
            whitespace >>
            (record_matcher | boolean_clause) >>
            whitespace.maybe >> newline
          )
        ).repeat >> (whitespace.maybe >> newline).repeat
      end

      rule(:inline_constraints) do
        (record_matcher | boolean_clause).repeat(1, 1) >>
          ((whitespace | newline).repeat >> (record_matcher | boolean_clause)).repeat
      end

      rule(:record_matcher) do
        class_name.as(:class_name) >>
          str("(") >>
          (
            (
              whitespace.maybe >> boolean_clause.repeat(1, 1) >> whitespace.maybe
            ) >> (
              str(",") >> whitespace.maybe >> boolean_clause >> whitespace.maybe
            ).repeat
          ).maybe.as(:boolean_clauses) >>
          str(")")
      end

      rule(:boolean_clause) do
        (
          expression.as(:lhs) >> whitespace.maybe >>
          comparison.as(:comparison) >> whitespace.maybe >>
          expression.as(:rhs)
        ) | (
          str("<") >> name.as(:simple_name_clause) >> str(">")
        ) | (
          str("not").as(:operation) >> whitespace.maybe >>
          str("{") >> (whitespace | newline).repeat >>
          inline_constraints.as(:constraints) >> (whitespace | newline).repeat >>
          str("}")
        )
      end

      rule(:comparison) do
        (str("=") | str("!=") | str("<=") | str("<") | str(">=") | str(">"))
      end

      # ===========
      # Expressions
      # ===========

      rule(:expression) do
        infix_expression(
          ((str("(") >> expression >> str(")")) |
           (str("<") >> name.as(:binding_name) >> str(">")) |
           count |
           sum |
           boolean |
           string |
           number |
           integer |
           nil_expr |
           name.as(:record_name)),
          [whitespace.maybe >> match("[+-]").as(:op) >> whitespace.maybe, 1, :left],
          [whitespace.maybe >> match("[*/]").as(:op) >> whitespace.maybe, 2, :left]
        ) { |l, o, r| { lhs: l, op: o[:op], rhs: r } }
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

      rule(:count) do
        str("count").as(:operation) >> whitespace.maybe >>
          (
            str("(") >> (whitespace | newline).repeat >>
            expression.as(:expression) >> (whitespace | newline).repeat >>
            str(")")
          ).maybe >> whitespace.maybe >>
          str("{") >> (whitespace | newline).repeat >>
          inline_constraints.as(:constraints) >> (whitespace | newline).repeat >>
          str("}")
      end

      rule(:sum) do
        str("sum").as(:operation) >> whitespace.maybe >>
          str("(") >> (whitespace | newline).repeat >>
          expression.as(:expression) >> (whitespace | newline).repeat >>
          str(")") >> whitespace.maybe >>
          str("{") >> (whitespace | newline).repeat >>
          inline_constraints.as(:constraints) >> (whitespace | newline).repeat >>
          str("}")
      end

      # ===============================
      # Ruby code blocks (just strings)
      # ===============================

      rule(:on_match) do
        str("on") >> whitespace >> str("match") >> whitespace.maybe >> newline >>
          (whitespace >> (eol.absent? >> any).repeat.as(:line) >> eol).repeat
      end

      rule(:on_update) do
        str("on") >> whitespace >> str("update") >> whitespace.maybe >> newline >>
          (whitespace >> (eol.absent? >> any).repeat.as(:line) >> eol).repeat
      end

      rule(:on_unmatch) do
        str("on") >> whitespace >> str("unmatch") >> whitespace.maybe >> newline >>
          (whitespace >> (eol.absent? >> any).repeat.as(:line) >> (eol | any.absent?)).repeat
      end

      # ================
      # Simple terminals
      # ================

      rule(:name) do
        (match("[a-zA-Z_]") >> match("[a-zA-Z_0-9!?]").repeat)
      end

      rule(:class_name) do
        (name >> (str("::") >> name).repeat)
      end

      rule(:whitespace) { match('[ \t]').repeat(1) }

      rule(:eol) do
        str("\r\n") | str("\n") | str(";") # treat semicolons like newlines!
      end

      rule(:newline) do
        (str("#") >> (eol.absent? >> any).repeat).maybe >> eol
      end
    end
  end
end
