# frozen_string_literal: true

require "active_record_rules/ast/expression_node"

module ActiveRecordRules
  module Ast
    class JsonLookup < ExpressionNode
      attr_reader :expression, :json_field_expression

      def initialize(expression, json_field_expression)
        super()
        @expression = expression
        @json_field_expression = json_field_expression
      end

      def to_query(definer)
        emitter = @expression.to_query(definer)
        json_field_emitter = @json_field_expression.to_query(definer)
        lambda do |bindings|
          "#{emitter.call(bindings)}->#{json_field_emitter.call(bindings)}"
        end
      end

      def relevant_change?(klass, previous, current)
        extract_value(previous) != extract_value(current)
      rescue StandardError
        @expression.relevant_change?(klass, previous, current) ||
          @json_field_expression.relevant_change?(klass, previous, current)
      end

      def record_relevant_attributes(tracker)
        @expression.record_relevant_attributes(tracker)
        @json_field_expression.record_relevant_attributes(tracker)
      end

      def deconstruct = [@expression, @json_field_expression]

      def extract_value(attributes)
        case @json_field_expression
        in Constant(field)
          @expression.extract_value(attributes)[field]
        else
          raise "Cannot extract value from attributes for non-constant field."
        end
      end

      def unparse
        case @json_field_expression
        in Constant(value)
          "#{@expression.unparse}.#{value}"
        else
          "#{@expression.unparse}[#{@json_field_expression}]"
        end
      end
    end
  end
end
