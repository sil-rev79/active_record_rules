# frozen_string_literal: true

require "parslet"

module ActiveRecordRules
  module Parse
    module Ast
      class Node
        # Convert this node into a textual representation which can be
        # parsed again.
        def unparse
          raise NotImplementedError, "No unparse method defined on #{self.class}"
        end
      end

      class ExpressionNode < Node
        def read_variables = Set.new
        def record_names = Set.new
        def to_arel(_) = (raise NotImplementedError, "No to_arel method defined on #{self.class}")
      end

      class Constant < ExpressionNode
        attr_reader :value

        def initialize(value)
          super()
          @value = value
        end

        def to_arel(_) = Arel::Nodes.build_quoted(@value)
        def to_sql(_klass, _json_field, _bindings) = ActiveRecord::Base.connection.quote(@value)
        def unparse = @value.nil? ? "nil" : @value.to_json
      end

      class Variable < ExpressionNode
        attr_reader :name

        def initialize(name)
          super()
          @name = name
        end

        def to_arel(_) = (raise "Variables cannot be evaluated during Condition filtering. You've found a bug!")
        def to_sql(_klass, _json_field, bindings) = bindings[name] || nil
        def read_variables = Set.new([name])
        def unparse = "<#{@name}>"
      end

      class RecordField < ExpressionNode
        attr_reader :name

        def initialize(name)
          super()
          @name = name
        end

        def to_sql(klass, json_field, _bindings)
          cast(
            "(#{json_field}->>'#{@name}')",
            klass&.attribute_types&.[](@name)&.type
          )
        end

        def to_arel(table) = table[@name]
        def record_names = Set.new([@name])
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

      class BinaryOperatorExpression < ExpressionNode
        attr_reader :lhs, :operator, :rhs

        def initialize(lhs, operator, rhs)
          super()
          @lhs = lhs
          @operator = operator
          @rhs = rhs
        end

        def to_arel(table)
          @lhs.to_arel(table)
              .public_send(@operator,
                           @rhs.to_arel(table))
        end

        def to_sql(klass, json_field, bindings)
          return unless (lhs_sql = @lhs.to_sql(klass, json_field, bindings))
          return unless (rhs_sql = @rhs.to_sql(klass, json_field, bindings))

          "(#{lhs_sql} #{@operator} #{rhs_sql})"
        end

        def read_variables = @lhs.read_variables + @rhs.read_variables
        def record_names = @lhs.record_names + @rhs.record_names
        def unparse = "#{@lhs.unparse} #{@operator} #{@rhs.unparse}"
      end

      class Comparison < ExpressionNode
        attr_reader :lhs, :comparison, :rhs

        def initialize(lhs, comparison, rhs)
          super()
          @lhs = lhs
          @comparison = comparison
          @rhs = rhs
        end

        def to_arel(table)
          @lhs.to_arel(table)
              .public_send(comparison_method,
                           @rhs.to_arel(table))
        end

        def to_sql(klass, json_field, bindings)
          return unless (lhs_sql = @lhs.to_sql(klass, json_field, bindings))
          return unless (rhs_sql = @rhs.to_sql(klass, json_field, bindings))
          return if @comparison == "=" && lhs_sql == rhs_sql

          "(#{lhs_sql} #{@comparison} #{rhs_sql})"
        end

        def bound_variables
          @bound_variables ||=
            case [@lhs, @comparison, @rhs]
            in [Variable, "=", Variable]
              { @lhs.name => @rhs,
                @rhs.name => @lhs }
            in [Variable, "=", value]
              { @lhs.name => value }
            in [value, "=", Variable]
              { @rhs.name => value }
            else
              {}
            end
        end

        def read_variables = @lhs.read_variables + @rhs.read_variables
        def record_names = @lhs.record_names + @rhs.record_names
        def unparse = "#{@lhs.unparse} #{@comparison} #{@rhs.unparse}"

        private

        def comparison_method
          {
            "=" => :eq,
            "!=" => :not_eq,
            "<" => :lt,
            "<=" => :lte,
            ">" => :gt,
            ">=" => :gte
          }.fetch(@comparison)
        end
      end

      class RecordMatcher < Node
        attr_reader :negated, :class_name, :clauses

        def initialize(negated, class_name, clauses)
          super()
          @negated = negated
          @class_name = class_name
          @clauses = (clauses || []).freeze
        end

        def bound_variable_names
          @bound_variable_names ||=
            @clauses.map { _1.bound_variables.keys.to_set }.reduce(&:+)
        end

        def record_names
          @record_names ||= @clauses.map(&:record_names).reduce(&:+)
        end

        # Return the same record matcher, but with only clauses which
        # do not read any variables.
        def only_simple_clauses
          RecordMatcher.new(
            @negated,
            @class_name,
            @clauses.select do |clause|
              clause.read_variables.empty? && clause.bound_variables.empty?
            end
          )
        end

        # Return the same record matcher, but with only clauses which
        # read, or bind, variables.
        def only_complex_clauses
          RecordMatcher.new(
            @negated,
            @class_name,
            @clauses.select do |clause|
              clause.read_variables.any? || clause.bound_variables.any?
            end
          )
        end

        def unparse = "#{@negated ? "not " : ""}#{@class_name}(#{@clauses.map(&:unparse).join(", ")})"
      end

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

        def unparse
          on_match = @on_match && "on_match\n  #{@on_match.split("\n").join("\n  ")}\n"
          on_update = @on_update && "on_update\n  #{@on_update.split("\n").join("\n  ")}\n"
          on_unmatch = @on_unmatch && "on_unmatch\n  #{@on_unmatch.split("\n").join("\n  ")}\n"
          <<~RULE
            rule #{@name}
              #{@constraints.map(&:unparse).join("\n  ")}
            #{on_match}#{on_update}#{on_unmatch}
          RULE
        end
      end
    end
  end
end
