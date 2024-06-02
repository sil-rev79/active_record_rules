# frozen_string_literal: true

require "active_record_rules/ast/expression_node"

module ActiveRecordRules
  module Ast
    class JsonLookup < ExpressionNode
      attr_reader :expression, :json_path, :type

      def initialize(expression, json_path, type)
        super()
        @expression = expression
        @json_path = json_path
        @type = type
      end

      def to_query(definer)
        emitter = @expression.to_query(definer)
        path_emitters = @json_path.map { _1.to_query(definer) }
        lambda do |bindings|
          expr = emitter.call(bindings)
          path_parts = path_emitters.map { _1.call(bindings) }
          case ActiveRecordRules.dialect
          in :postgres
            array = false
            json_bit = path_parts.reduce("@#{expr}!") do |e, part|
              if part == "'*'"
                array = true
                e.sub(/@([^!]+)!/, "(select @e! from jsonb_array_elements(\\1) as e order by 1)")
              else
                e.sub(/@([^!]+)!/, "@(\\1)->#{part}!")
              end
            end
            if array
              raise "Array JSON selection needs array type: #{unparse}" unless type.end_with?("[]")

              json_bit.sub(/@([^!]+)!/, "array_agg(((\\1)#>>'{}') :: #{type[0..-3]})")
            else
              json_bit.sub(/@([^!]+)!/, "((\\1)#>>'{}') :: #{type}")
            end
          in :sqlite
            array = false
            json_bit = path_parts.reduce("@#{expr}!") do |e, part|
              if part == "'*'"
                array = true
                e.sub(/@([^!]+)!/, "(select @json_each.value! from json_each(\\1) order by 1)")
              else
                e.sub(/@([^!]+)!/, "@(\\1)->#{part}!")
              end
            end
            if array
              raise "Array JSON selection needs array type: #{unparse}" unless type.end_with?("[]")

              json_bit.sub(/@([^!]+)!/, "json_group_array(\\1)")
            else
              json_bit.sub(/@([^!]+)!/, "\\1")
            end
          end
        end
      end

      def relevant_change?(klass, previous, current)
        case @expression
        in RecordField(name)
          prev = [previous[name]]
          curr = [current[name]]

          @json_path.each do |part|
            case part
            in Constant("*")
              prev.flatten!(1)
              curr.flatten!(1)
            in Constant(field)
              prev.map! { _1.nil? ? nil : _1[field] }
              curr.map! { _1.nil? ? nil : _1[field] }
            else
              return @expression.relevant_change?(klass, previous, current) ||
                     @json_path.relevant_change?(klass, previous, current)
            end
          end

          prev != curr
        else
          @expression.relevant_change?(klass, previous, current) ||
            @json_path.relevant_change?(klass, previous, current)
        end
      end

      def record_relevant_attributes(tracker)
        @expression.record_relevant_attributes(tracker)
        @json_path.any? { _1.record_relevant_attributes(tracker) }
      end

      def deconstruct = [@expression, @json_path]

      def unparse
        @json_path.reduce(expression.unparse) do |expr, part|
          case part
          in Constant(value)
            "#{expr}.#{value}"
          else
            "#{expr}[#{part.unparse}]"
          end
        end
      end
    end
  end
end
