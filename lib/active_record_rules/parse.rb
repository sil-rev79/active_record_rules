# frozen_string_literal: true

require "active_record_rules/ast"
require "active_record_rules/parse/parser"
require "active_record_rules/parse/transform"

module ActiveRecordRules
  module Parse # :nodoc:
    class ParseFailed < StandardError; end

    class << self
      def definitions(input) = run(:definitions, input)
      def definition(input) = run(:definition, input)
      def constraints(input) = run(:constraints, input)
      def constraint(input) = run(:constraint, input)
      def boolean_clause(input) = run(:boolean_clause, input)

      private

      def parser = Parser.new
      def transform = Transform.new

      def run(rule, input)
        transform.apply(parser.send(rule).parse(input, reporter: Parslet::ErrorReporter::Deepest.new))
      rescue Parslet::ParseFailed => e
        raise ParseFailed, e.parse_failure_cause.ascii_tree
      end
    end
  end
end
