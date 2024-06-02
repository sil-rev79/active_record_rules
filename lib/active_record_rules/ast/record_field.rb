# frozen_string_literal: true

require "active_record_rules/ast/expression_node"

module ActiveRecordRules
  module Ast
    class RecordField < ExpressionNode
      attr_reader :name

      def initialize(location, name, flags = nil)
        super()
        @location = location
        @name = name
        @flags = flags || ""
      end

      def to_query(definer)
        klass = definer.table_class
        lambda do |_|
          type = klass.attribute_types[@name]&.type
          case type
          in nil
            raise "Unknown attribute referenced in rule: #{klass}##{@name} (at #{@location.join(":")})"
          in :integer
            if (defn = klass.defined_enums[@name])
              if @flags.include?("i")
                # as an integer
                "#{definer.table_name}.#{@name}"
              elsif @flags.include?("s")
                # as a string
                clauses = defn.map do |value, key|
                  "when #{definer.table_name}.#{@name} = #{key} then #{ActiveRecord::Base.connection.quote(value)}"
                end
                "case #{clauses.join("\n     ")}\nend"
              else
                raise "Don't know what to return for enum #{definer.table_class}##{@name}: " \
                      "add :i or :s to cast to int/string (at #{@location.join(":")})"
              end
            else
              unless @flags.empty?
                ActiveRecordRules.logger&.warn do
                  "Flags provided for #{definer.table_class}##{@name}, but attribute is not an enum"
                end
              end

              "#{definer.table_name}.#{@name}"
            end
          else
            "#{definer.table_name}.#{@name}"
          end
        end
      end

      def relevant_change?(_, previous, current)
        previous[@name] != current[@name]
      end

      def record_relevant_attributes(tracker)
        tracker.add(@name)
      end

      def deconstruct = [@name]

      def unparse = @name
    end
  end
end
