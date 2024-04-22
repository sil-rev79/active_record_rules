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

      def table_name
        @table_name ||= @class.table_name
      end

      def to_query(definer)
        table_definer = definer.define_table(table_name) do |_bindings|
          table_name
        end

        definer.add_binding("__id_#{table_definer.table_name}") do
          "#{table_definer.table_name}.id"
        end

        @clauses.each do |clause|
          emitter = clause.to_query(table_definer)
          table_definer.add_condition(&emitter) if emitter
        end

        nil
      end

      def bound_names
        @bound_names ||= @clauses.map(&:bound_names).reduce(&:+)
      end

      def unparse = "#{@negated ? "not " : ""}#{@class_name}(#{@clauses.map(&:unparse).join(", ")})"
    end
  end
end
