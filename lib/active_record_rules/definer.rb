# frozen_string_literal: true

module ActiveRecordRules
  module Definer
    def define_rule(name, context: nil, &block)
      values = DefinitionContext.new
      values.instance_eval(&block)
      ActiveRecordRules.register_rule!(
        Rule.new(
          name: name,
          **values.to_h,
          context: context || self
        )
      )
    end

    class DefinitionContext
      def after_save(constraints) = save_timing(:after_save, constraints)
      def after_commit(constraints) = save_timing(:after_commit, constraints)
      def after_request(constraints) = save_timing(:after_request, constraints)
      def async(constraints) = save_timing(:async, constraints)

      def on_match(&block) = (@on_match = block)
      def on_update(&block) = (@on_update = block)
      def on_unmatch(&block) = (@on_unmatch = block)

      def to_h
        {
          timing: @timing,
          constraints: @constraints,
          on_match: @on_match,
          on_update: @on_update,
          on_unmatch: @on_unmatch
        }
      end

      private

      def save_timing(timing, constraints)
        raise "Multiple timing/constraint declarations (previously: #{@timing})" if @timing

        @timing = timing
        @constraints = Parse.constraints(constraints)
      end
    end
  end
end
