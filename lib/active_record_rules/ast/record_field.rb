# frozen_string_literal: true

require "active_record_rules/ast/expression_node"

module ActiveRecordRules
  module Ast
    class RecordField < ExpressionNode
      attr_reader :name

      def initialize(name)
        super()
        @name = name
      end

      def to_query(definer) = ->(_) { "#{definer.table_name}.#{@name}" }

      def to_sql(klass, json_field, _bindings)
        cast(
          "(#{json_field}->>'#{@name}')",
          klass&.attribute_types&.[](@name)&.type
        )
      end

      def relevant_change?(_, previous, current)
        previous[@name] != current[@name]
      end

      def record_relevant_attributes(tracker)
        tracker.add(@name)
      end

      def deconstruct = [@name]

      def unparse = @name

      private

      def cast(object, type)
        if ActiveRecordRules.dialect == :sqlite
          object # no need to cast in sqlite!
        elsif ActiveRecordRules.dialect == :postgres
          # TODO: make this mapping more reasonable
          sql_type = case type
                     in :integer | :float
                       "numeric"
                     in :string
                       "text"
                     in :datetime
                       "timestamp"
                     else
                       type || "any"
                     end
          "(#{object}) :: #{sql_type}"
        else
          raise "Unknown dialect: #{ActiveRecordRules.dialect}"
        end
      end
    end
  end
end
