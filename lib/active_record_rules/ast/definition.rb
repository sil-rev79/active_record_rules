# frozen_string_literal: true

require "active_record_rules/ast/node"
require "active_record_rules/query_definer"

module ActiveRecordRules
  module Ast
    class Definition < Node
      attr_reader :name, :constraints, :on_match, :on_update, :on_unmatch

      def initialize(name, constraints, on_match, on_update, on_unmatch)
        super()
        @name = name
        @constraints = constraints
        @on_match = on_match
        @on_update = on_update
        @on_unmatch = on_unmatch
      end

      def to_query_sql
        query_definer = QueryDefiner.new
        constraints.each do |constraint|
          emitter = constraint.to_query(query_definer)
          query_definer.add_condition(&emitter) if emitter
        end

        id_names, other_names = query_definer.bindings.keys.partition { _1.start_with?("__id_") }
        <<~SQL
          select #{json_sql(id_names)} as ids,
                 #{json_sql(other_names)} as arguments
            from (
              #{query_definer.to_sql.split("\n").join("\n    ")}
            ) as q
        SQL
      end

      def json_sql(names)
        args = names.map { "'#{remove_id_prefix(_1)}', #{_1}" }.join(", ")
        if ActiveRecordRules.dialect == :sqlite
          "json_object(#{args})"
        elsif ActiveRecordRules.dialect == :postgres
          "jsonb_build_object(#{args})"
        else
          raise "Unknown dialect: #{ActiveRecordRules.dialect}"
        end
      end

      def remove_id_prefix(string)
        if string.start_with?("__id_")
          string[5..]
        else
          string
        end
      end

      def bound_names
        @bound_names ||= constraints.map(&:bound_names).reduce(&:+)
      end

      def unparse
        on_match = @on_match && "on match\n  #{@on_match.split("\n").join("\n  ")}\n"
        on_update = @on_update && "on update\n  #{@on_update.split("\n").join("\n  ")}\n"
        on_unmatch = @on_unmatch && "on unmatch\n  #{@on_unmatch.split("\n").join("\n  ")}\n"
        [
          "rule #{@name}",
          "  #{@constraints.map(&:unparse).join("\n  ")}",
          "#{on_match}#{on_update}#{on_unmatch}"
        ].join("\n")
      end
    end
  end
end
