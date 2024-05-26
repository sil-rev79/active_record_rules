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

    def define_table(name)
      table_name = "#{name}_#{next_index}"
      @tables[table_name] = name
      TableDefiner.new(self, table_name)
    end

    def add_binding(name, &make_definition)
      @bindings[name] << make_definition
      nil
    end

    def add_condition(&make_condition)
      @conditions << make_condition
      nil
    end

    def to_sql(outer_bindings = {}, interesting_binding_names = nil)
      resolving = Set.new
      all_bindings = {}
      resolved_bindings = Hash.new do |hash, key|
        raise "Circular variable reference containing: #{resolving}" unless resolving.add?(key)
        raise "Unknown variable reference: #{key}" unless @bindings.key?(key) || outer_bindings.key?(key)

        if @bindings.key?(key)
          # Note the circularity here. Bindings can refer to other
          # bindings, so we allow them to be resolved during resolution.
          all_bindings[key] = @bindings[key].map { _1.call(hash) }.sort_by(&:length)
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

      names = if interesting_binding_names
                interesting_binding_names & @bindings.keys
              else
                @bindings.keys
              end

      bindings = names.map { "#{resolved_bindings[_1].split("\n").join("\n        ")} as #{_1}" }.join(",\n       ")

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
        *@conditions.compact.map { _1.call(resolved_bindings) },
        *@bindings.keys.flat_map do |name|
          first = all_bindings[name][0]
          (all_bindings[name][1..] || []).map do |other|
            "#{first} is not distinct from #{other}"
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

    class TableDefiner
      def initialize(query_definer, table_name)
        @query_definer = query_definer
        @table_name = table_name
      end

      attr_reader :table_name

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
  end
end
