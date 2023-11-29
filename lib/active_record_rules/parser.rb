# frozen_string_literal: true

require "parslet"

module ActiveRecordRules
  class Parser < Parslet::Parser
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

    rule(:name) do
      (match("[a-zA-Z_]") >> match("[a-zA-Z_0-9!?]").repeat)
    end

    rule(:expression) do
      name.as(:name) | string | number
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

    rule(:activation) do
      str("on") >> whitespace >> str("activation") >> whitespace.maybe >> newline >>
        (whitespace >> (eol.absent? >> any).repeat.as(:line) >> eol).repeat
    end

    rule(:deactivation) do
      str("on") >> whitespace >> str("deactivation") >> whitespace.maybe >> newline >>
        (whitespace >> (eol.absent? >> any).repeat.as(:line) >> eol).repeat
    end

    rule(:definition) do
      str("rule") >> whitespace >>
        (newline.absent? >> any).repeat.as(:name) >> newline >>
        conditions.as(:conditions) >>
        activation.as(:activation).maybe >>
        deactivation.as(:deactivation).maybe
    end

    root :definition
  end
end
