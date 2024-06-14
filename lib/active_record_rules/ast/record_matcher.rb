# frozen_string_literal: true

require "active_record_rules/ast/node"

module ActiveRecordRules
  module Ast
    class RecordMatcher < Node
      attr_reader :class_name, :clauses

      def initialize(class_name, clauses)
        super()
        @class_name = class_name
        @class = Object.const_get(@class_name)
        @clauses = (clauses || []).freeze
        return if @class < ActiveRecord::Base

        raise "Record matches must be on subclasses of ActiveRecord::Base, not #{@class_name}"
      end

      def to_query(definer)
        table_definer = definer.define_table(@class)

        definer.add_binding("__id_#{table_definer.table_name}") do
          "#{table_definer.table_name}.id"
        end

        @clauses.each do |clause|
          case clause
          in BinaryOperatorExpression(Variable(left), "=", Variable(right))
            definer.add_binding(left) { _1[right] }
            definer.add_binding(right) { _1[left] }
          in BinaryOperatorExpression(Variable(left), "=", right)
            definer.add_binding(left, &right.to_query(table_definer))
          in BinaryOperatorExpression(left, "=", Variable(right))
            definer.add_binding(right, &left.to_query(table_definer))
          else
            emitter = clause.to_query(table_definer)
            table_definer.add_condition(&emitter) if emitter
          end
        end

        nil
      end

      def relevant_change?(klass, previous, current)
        return false unless klass <= @class

        @clauses.any? do |clause|
          clause.relevant_change?(klass, previous, current)
        end
      end

      def record_relevant_attributes(tracker)
        subtracker = tracker.for_class(@class)
        @clauses.each { _1.record_relevant_attributes(subtracker) }
      end

      def deconstruct = [@class, @clauses]
      def unparse = "#{@class_name}(#{@clauses.map(&:unparse).join(", ")})"
    end
  end
end
