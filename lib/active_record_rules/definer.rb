# frozen_string_literal: true

module ActiveRecordRules
  module Definer
    # Define a rule and register it with the global ActiveRecordRules
    # object.
    #
    # By default this will take the reciever as the evaluation context
    # for the rule bodies (on_match, on_update, on_unmatch).
    #
    # @param name [String] The name of this rule
    # @param context [any] The context to use when evaluating the rule (with bound vars added)
    # @yieldself [DefinitionContext] A builder used to define this rule
    def define_rule(name, context: nil, &block)
      values = DefinitionContext.new
      values.instance_eval(&block)
      rule = Rule.new(
        name: name,
        source_location: block.source_location.join(":"),
        **values.to_h,
        context: context || self
      )
      ActiveRecordRules.register_rule!(rule)
      rule
    end

    class DefinitionContext
      def after_save(constraints) = save_timing(:after_save, constraints)
      def after_commit(constraints) = save_timing(:after_commit, constraints)
      def after_request(constraints) = save_timing(:after_request, constraints)
      def later(constraints) = save_timing(:later, constraints)

      def on_match(&block)
        raise "Redefinition of on_match block not permitted" if @on_match

        @on_match = block
      end

      def on_update(&block)
        raise "Redefinition of on_update block not permitted" if @on_update

        @on_update = block
      end

      def on_unmatch(&block)
        raise "Redefinition of on_unmatch block not permitted" if @on_unmatch

        @on_unmatch = block
      end

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
        @constraints = constraints
      end
    end
  end
end
