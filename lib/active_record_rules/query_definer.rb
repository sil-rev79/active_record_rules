# frozen_string_literal: true

require "set"

module ActiveRecordRules
  class QueryDefiner
    attr_reader :tables, :bindings, :conditions

    def initialize(parent = nil)
      @parent = parent
      @tables = {}
      @bindings = Hash.new { _1[_2] = [] }
      @conditions = []
    end

    def define_table(klass)
      table_name = "#{klass.table_name}_#{next_index}"
      @tables[table_name] = klass.table_name
      TableDefiner.new(self, klass, table_name)
    end

    def add_binding(name, &make_definition)
      @bindings[name] << make_definition
      nil
    end

    def add_condition(&make_condition)
      @conditions << make_condition
      nil
    end

    class CircularReference < StandardError; end

    def to_sql(outer_bindings = {}, interesting_binding_names = nil)
      resolving = Set.new
      all_bindings = {}
      resolved_bindings = Hash.new do |hash, key|
        raise CircularReference, "Circular variable reference containing: #{resolving}" unless resolving.add?(key)
        raise "Unknown variable reference: #{key}" unless @bindings.key?(key) || outer_bindings.key?(key)

        if @bindings.key?(key)
          # Note the circularity here. Bindings can refer to other
          # bindings, so we allow them to be resolved during resolution.
          errors = []
          all_bindings[key] = @bindings[key].map do |builder|
            value = builder.call(hash)
            if value.is_a?(SqlExpr)
              value
            else
              SqlExpr.new(value, true)
            end
          rescue CircularReference => e
            errors << e
            nil
          end.compact.sort_by(&:length)
          if all_bindings[key].empty?
            raise errors.first if errors.size == 1

            raise "Errors resolving binding: #{e.map(&:message).join("; ")}"
          end

          hash[key] = all_bindings[key].first
        else
          hash[key] = outer_bindings[key]
        end
        raise key if hash[key].nil?
      ensure
        resolving.delete(key)
      end

      # Force them all to be calculated up-front.
      outer_bindings.each_key { resolved_bindings[_1] }
      @bindings.each_key { resolved_bindings[_1] }

      names = @bindings.keys
      names &= interesting_binding_names if interesting_binding_names

      bindings = names.map { "#{resolved_bindings[_1].sql.split("\n").join("\n        ")} as #{_1}" }.join(",\n       ")

      left_joins = []
      tables = @tables.map do |name, real_name|
        "#{real_name} as #{name}"
      end.compact.join("\n cross join ")
      tables += left_joins.map do |name, definition, on_condition|
        on = on_condition.call(name, resolved_bindings)
        on = "true" if on.empty?
        "\n  left join #{definition.call(resolved_bindings).split("\n").join("\n             ")}" \
          "\n         as #{name}" \
          "\n         on #{on.split("\n").join("\n     ")}"
      end.join

      conditions = [
        *@conditions.compact.map do |condition|
          clause = condition.call(resolved_bindings)
          if clause.sql.end_with?(" is true")
            # In the context of a where clause, the "is true" is
            # unnecessary, because NULL is interpreted as
            # false. However, leaving the "is true" there
            # prevents Postgres from using indexes, so stripping
            # it off is *really* useful.
            clause.sql[0...-" is true".size]
          else
            clause.sql
          end
        end,
        *outer_bindings.flat_map do |name, value|
          (all_bindings[name] || []).map do |other|
            gen_eq(value, other)
          end
        end,
        *all_bindings.values.flat_map do |values|
          first = values[0]
          (values[1..] || []).map do |other|
            gen_eq(first, other)
          end
        end
      ].join("\n   and ")

      if tables.first == "\n"
        raise "Invalid query: cannot emit query without a positive table reference. " \
              "Do you have a `not { not { ... } }' in your query?"
      end

      [
        "select #{bindings}",
        "  from #{tables}",
        (" where #{conditions.split("\n").join("\n       ")}" unless conditions.empty?)
      ].compact.join("\n")
    end

    SqlExpr = Struct.new(:sql, :nullable?) do
      def to_s = sql.to_s
      def length = sql.length
    end

    class TableDefiner
      def initialize(query_definer, table_class, table_name)
        @query_definer = query_definer
        @table_class = table_class
        @table_name = table_name
      end

      attr_reader :table_class, :table_name

      def method_missing(name, *args, **kwargs, &block) = @query_definer.public_send(name, *args, **kwargs, &block)
      def respond_to_missing?(name) = @query_definer.respond_to?(name)
    end

    def next_index
      if @parent
        @parent.next_index
      else
        @counter ||= 0
        @counter += 1
      end
    end

    def gen_eq(left, right)
      case [ left.to_s, right.to_s ]
      in "NULL", "NULL"
        "TRUE"
      in "NULL", _
        "#{right} is NULL"
      in _, "NULL"
        "#{left} is NULL"
      else
        if left.nullable? && right.nullable?
          "(#{left.sql} = #{right.sql} or (#{left.sql} is null and #{right.sql} is null))"
        else
          "#{left.sql} = #{right.sql}"
        end
      end
    end
  end
end
