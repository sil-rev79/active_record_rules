# frozen_string_literal: true

module ActiveRecordRules
  class Clause
    class << self
      def parse(input, record_class = nil)
        input = Parser.new.clause.parse(input) if input.is_a?(String)

        case input
        in { lhs:, op:, rhs: }
          BinaryOperatorExpression.new(
            process_expr(lhs, record_class),
            op.to_s,
            process_expr(rhs, record_class)
          )
        in { name: }
          BinaryOperatorExpression.new(
            RecordVariable.new(name.to_s, record_class),
            "=",
            BindingVariable.new(name.to_s)
          )
        end
      end

      private

      def process_expr(expr, record_class)
        case expr
        in { lhs:, op:, rhs: }
          BinaryOperatorExpression.new(
            process_expr(lhs, record_class),
            op.to_s,
            process_expr(rhs, record_class)
          )
        in { binding_name: }
          BindingVariable.new(binding_name.to_s)
        in { record_name: }
          RecordVariable.new(record_name.to_s, record_class)
        in { boolean: }
          Constant.new(boolean.to_s == "true")
        in { string: }
          Constant.new(string.to_s)
        in { number: }
          Constant.new(number.to_i)
        in { nil: _ }
          Constant.new(nil)
        end
      end
    end

    def binds_variables? = false
    def record_variables = Set.new

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

  class BinaryOperatorExpression < Clause
    attr_reader :left, :operator, :right

    def initialize(left, operator, right)
      super()
      @left = left
      @operator = operator
      @right = right
    end

    def binds_variables? = @left.binds_variables? || @right.binds_variables?
    def record_variables = @left.record_variables + @right.record_variables

    def to_bindings
      return {} unless operator == "="
      return {} unless left.is_a?(BindingVariable) || right.is_a?(BindingVariable)

      if left.is_a?(BindingVariable) && right.is_a?(BindingVariable)
        { left.name => right, right.name => left }
      elsif left.is_a?(BindingVariable)
        { left.name => right }
      else
        { right.name => left }
      end
    end

    def to_arel(table, bindings)
      left_arel = left.to_arel(table, bindings)
      right_arel = right.to_arel(table, bindings)
      op_method = {
        "=" => :eq,
        "!=" => :not_eq,
        "<" => :lt,
        "<=" => :lte,
        ">" => :gt,
        ">=" => :gte
      }.fetch(operator)
      left_arel.send(op_method, right_arel)
    end

    def to_rule_sql(json_field, bindings)
      return unless (left_sql = left.to_rule_sql(json_field, bindings))
      return unless (right_sql = right.to_rule_sql(json_field, bindings))
      return if operator == "=" && left_sql == right_sql

      op = if operator == "++"
             "||"
           else
             operator
           end

      "(#{left_sql} #{op} #{right_sql})"
    end

    def evaluate(object)
      left_object = left.evaluate(object)
      right_object = right.evaluate(object)
      op_method = if operator == "="
                    "=="
                  elsif operator == "++"
                    "+"
                  else
                    operator
                  end
      left_object.public_send(op_method, right_object)
    end

    def unparse = "#{left.unparse} #{operator} #{right.unparse}"
  end

  class BindingVariable < Clause
    attr_reader :name

    def initialize(name)
      super()
      @name = name
    end

    def binds_variables? = true

    def to_arel(_table, bindings) = bindings[name]

    def to_rule_sql(_json_field, bindings) = bindings[name] || nil

    def evaluate(_object)
      raise "Can't evaluate BindingVariable(#{name})"
    end

    def unparse = "<#{name}>"
  end

  class RecordVariable < Clause
    attr_reader :name, :type

    def initialize(name, record_class)
      super()
      @name = name
      @type = record_class&.attribute_types&.[](name)&.type
    end

    def record_variables = Set.new([name])

    def to_arel(table, _bindings) = table[name]

    def to_rule_sql(json_field, _bindings) = cast("(#{json_field}->>'#{name}')", type)

    def evaluate(object) = object[name]

    def unparse = name
  end

  class Constant < Clause
    attr_reader :value

    def initialize(value)
      super()
      @value = value
    end

    def to_arel(_table, _bindings) = Arel::Nodes.build_quoted(value)

    def to_rule_sql(_json_field, _bindings) = ActiveRecord::Base.connection.quote(value)

    def evaluate(_object) = value

    def unparse = value.nil? ? "nil" : value.to_json
  end
end
