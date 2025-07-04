module ActiveRecordRules
  class RulesController < ApplicationController
    include ActionView::Helpers::TagHelper

    cattr_accessor :format_record_proc, default: ->(record) { record.id.inspect }

    def index
      @model_name = params["model_name"].presence
      @record_id = params["record_id"].presence

      @models = ActiveRecordRules.all_rules.map do |rule|
        rule.referenced_classes.map(&:name)
      end.reduce(Set.new, &:+).sort

      @rules_and_matches = ActiveRecordRules.all_rules.map do |rule|
        klass = rule.referenced_classes.find { _1.name == @model_name }
        if @model_name && !klass
          nil # The rule doesn't mention the selected class, so don't show it
        elsif @model_name && @record_id
          if (record = klass.find_by(id: @record_id))
            [ rule, rule.rule_matches_for(record).size ]
          else
            [ rule, 0 ]
          end
        else
          [ rule, rule.rule_matches.size ]
        end
      end.compact
    end

    def show
      @model_name = params["model_name"].presence
      @record_id = params["record_id"].presence
      @page = params["page"].to_i

      @rule = ActiveRecordRules.find_rule(params["id"].to_i)
      render "not-found" unless @rule

      @models = @rule.referenced_classes.map(&:name).sort
      klass = @rule.referenced_classes.find { _1.name == @model_name }

      @record = klass.find_by(id: @record_id) if @model_name && @record_id
      if @record_id
        matches = @rule.rule_matches_for(@record)
      else
        matches = @rule.rule_matches
      end

      page_size = 20
      @max_page = (matches.size / page_size.to_f).ceil - 1
      @id_objects = matches
                    .drop(@page.to_i * page_size)
                    .take(page_size)
                    .map do |rule_match|
        [ rule_match,
         @rule.id_names_and_types.to_h do |name, type|
           [ name, type.find_by(id: rule_match.ids[name]) ]
         end ]
      end
    end

    def trigger
      @rule = ActiveRecordRules.find_rule(params["id"].to_i)
      render "not-found" unless @rule

      @model_name = params["model_name"].presence
      @record_id = params["record_id"].presence
      klass = @rule.referenced_classes.find { _1.name == @model_name }
      @record = klass.find_by(id: @record_id) if @model_name && @record_id

      pending_activations = if @record
                              @rule.calculate_required_activations(@record.class, nil, @record.attributes)
      end
      ActiveRecordRules.run_pending_executions(@rule.activate(pending_activations))

      path = [ "model_name", "record_id", "page" ].index_with { params[_1] }
      redirect_to rule_path(path), status: 303
    end

    def show_match
      @model_name = params["model_name"].presence
      @record_id = params["record_id"].presence
      @page = params["page"].to_i

      @rule = ActiveRecordRules.find_rule(params["rule_id"].to_i)
      render "not-found" unless @rule

      @rule_match = @rule.rule_matches.find(params["match_id"].to_i)
      render "not-found" unless @rule_match

      id_paths = @rule.extract_id_variables

      @live_arguments = @rule_match.live_arguments
      @next_arguments = @rule_match.next_arguments

      @argument_keys = @live_arguments&.keys.to_a | @next_arguments&.keys.to_a
      if @live_arguments
        @live_objects = id_paths.reduce(@live_arguments) do |result, (path, klass)|
          replace_ids(result, path, klass)
        end.transform_values { format_value(_1) }
      end

      if @next_arguments
        @next_objects = id_paths.reduce(@next_arguments) do |result, (path, klass)|
          replace_ids(result, path, klass)
        end.transform_values { format_value(_1) }
      end
    end

    private

    def replace_ids(arguments, path, klass)
      case [ path, arguments ]
      in [[], id]
        klass.find_by(id: id) || id
      in [[:all, *rest], _]
        arguments.map { replace_ids(_1, rest, klass) }
      in [[key, *rest], Hash => arguments]
        if arguments.key?(key)
          { **arguments, key => replace_ids(arguments[key], rest, klass) }
        else
          arguments
        end
      in [[key, *rest], Array => arguments]
        [ *arguments[...key], replace_ids(arguments[key], rest, klass), *arguments[key+1..] ]
      end
    end

    def format_value(value)
      tags = PrettyPrint.format(
        # output: an array to store tags
        [],
        # maxwidth:
        120,
        # newline:
        tag.br,
        # genspace:
        ->(n) { " " * n }
      ) { format_one_value(value, _1) }

      # We start the reduction with a HTML-safe string, so the result
      # keeps track of its safety along the way.
      tags.reduce("".html_safe, &:+)
    end

    def format_one_value(value, printer)
      case value
      in Array
        if value.empty?
          printer.text("[]", 2)
        else
          printer.text("[ ")
          printer.group(2) do
            value.each_with_index do |item, i|
              if i > 0
                printer.text(",")
                printer.breakable
              end
              format_one_value(item, printer)
            end
          end
          printer.text(" ]")
        end
      in ActiveRecord::Base
        string = format_record(value)
        printer.text(
          begin
            tag.a(string, href: main_app.url_for(value))
          rescue => e
            string
          end,
          string.length
        )
      else
        printer.text(value.inspect)
      end
    end

    helper_method :format_record

    def format_record(record)
      instance_exec(record, &self.class.format_record_proc)
    end
  end
end
