# frozen_string_literal: true

require "parslet"

module ActiveRecordRules
  class Parser < Parslet::Parser # :nodoc:
    rule(:whitespace) { match('[ \t]').repeat(1) }

    rule(:eol) do
      str("\r\n") | str("\n")
    end

    rule(:newline) do
      (str("#") >> (eol.absent? >> any).repeat).maybe >> eol
    end

    rule(:string) do
      str('"') >>
        (
          (str("\\") >> any) |
          (str('"').absent? >> any)
        ).repeat.as(:string) >>
        str('"')
    end

    rule(:number) do
      (
        match("[0-9]").repeat(1) >>
        (str(".") >> match("[0-9]").repeat).maybe
      ).as(:number)
    end

    rule(:boolean) do
      (str("true") | str("false")).as(:boolean) >> match("[a-zA-Z0-9]_!?").absent?
    end

    rule(:nil_expr) do
      str("nil").as(:nil) >> match("[a-zA-Z0-9]_!?").absent?
    end

    rule(:name) do
      (match("[a-zA-Z_]") >> match("[a-zA-Z_0-9!?]").repeat)
    end

    rule(:class_name) do
      name >> (str("::") >> name).repeat
    end

    rule(:expression) do
      boolean |
        string |
        number |
        nil_expr |
        (str("<") >> name.as(:binding_name) >> str(">")) |
        name.as(:record_name)
    end

    rule(:operator) do
      (str("=") | str("!=") | str("<=") | str("<") | str(">=") | str(">")).as(:op)
    end

    rule(:clause) do
      (str("<") >> name.as(:name) >> str(">")) |
        (expression.as(:lhs) >> whitespace.maybe >> operator >> whitespace.maybe >> expression.as(:rhs))
    end

    rule(:condition) do
      (str("not") >> whitespace).maybe.as(:negated) >>
        class_name.as(:class_name) >>
        str("(") >>
        (
          (
            whitespace.maybe >> clause.repeat(1, 1) >> whitespace.maybe
          ) >> (
            str(",") >> whitespace.maybe >> clause >> whitespace.maybe
          ).repeat
        ).maybe.as(:clauses) >>
        str(")")
    end

    rule(:conditions) do
      (newline | (whitespace >> condition.maybe >> whitespace.maybe >> newline)).repeat
    end

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

    rule(:definition) do
      str("rule") >> whitespace >>
        (newline.absent? >> any).repeat.as(:name) >> newline >>
        conditions.as(:conditions) >>
        on_match.as(:on_match).maybe >>
        on_update.as(:on_update).maybe >>
        on_unmatch.as(:on_unmatch).maybe
    end

    rule(:definitions) do
      ((whitespace | newline).repeat >> definition.as(:definition)).repeat >> (whitespace | newline).repeat
    end
  end
end
