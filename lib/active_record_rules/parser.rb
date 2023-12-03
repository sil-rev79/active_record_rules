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

    rule(:name) do
      (match("[a-zA-Z_]") >> match("[a-zA-Z_0-9!?]").repeat)
    end

    rule(:expression) do
      boolean | string | number | name.as(:name)
    end

    rule(:operation) do
      (str("=") | str("!=") | str("<=") | str("<") | str(">=") | str(">")).as(:op)
    end

    rule(:condition_part) do
      name.as(:name) >> whitespace.maybe >> (operation >> whitespace.maybe >> expression.as(:rhs)).maybe
    end

    rule(:condition) do
      name.as(:class_name) >>
        str("(") >>
        (
          (
            whitespace.maybe >> condition_part.repeat(1, 1) >> whitespace.maybe
          ) >> (
            str(",") >> whitespace.maybe >> condition_part >> whitespace.maybe
          ).repeat
        ).maybe.as(:parts) >>
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
        (whitespace >> (eol.absent? >> any).repeat.as(:line) >> eol).repeat
    end

    rule(:definition) do
      str("rule") >> whitespace >>
        (newline.absent? >> any).repeat.as(:name) >> newline >>
        conditions.as(:conditions) >>
        on_match.as(:on_match).maybe >>
        on_update.as(:on_update).maybe >>
        on_unmatch.as(:on_unmatch).maybe
    end

    root :definition
  end
end
