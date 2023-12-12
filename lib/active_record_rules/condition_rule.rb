# frozen_string_literal: true

module ActiveRecordRules
  # A join between Condition and Rules. Each ConditionRule also has a
  # key which is used to refer to the objects matching it when rule
  # constraints are checked.
  #
  # ConditionRules perform two functions:
  #
  #  1. associate the condition with a name, so they can be referenced
  #     in Rule constraints
  #
  #  2. store the relevant fields (in ConditionRuleMemory objects) to
  #     avoid triggering rules on irreleveant updates
  class ConditionRule < ActiveRecord::Base
    self.table_name = :arr__condition_rules

    belongs_to :condition
    has_many :condition_rule_matches, dependent: :destroy
    belongs_to :rule
    validates :key, uniqueness: { scope: :rule }

    def activate(object)
      values = fields.to_h { [_1, object[_1]] }

      if (match = condition_rule_matches.find_by(entry_id: object.id))
        old_values = match.values
        match.update!(values: values)

        logger&.info { "ConditionRule(#{id}): updated for #{object.class}(#{object.id})" }
        logger&.debug { "ConditionRule(#{id}): updated for #{values} (previously: #{old_values})" }
        rule.update(key, object, old_values, values) unless old_values == values
      else
        logger&.info { "ConditionRule(#{id}): matched for #{object.class}(#{object.id})" }
        logger&.debug { "ConditionRule(#{id}): matched with values #{values}" }
        condition_rule_matches.create!(
          entry_id: object.id,
          values: values
        )

        rule.activate(key, object, values)
      end
    end

    def deactivate(object)
      condition_rule_matches.destroy_by(entry_id: object.id)&.each do |match|
        logger&.debug do
          "ConditionRule(#{id}): unmatched for #{object.class}(#{object.id}) (condition no longer matches)"
        end
        rule.deactivate(key, object, match.values)
      end
    end

    private

    def logger
      ActiveRecordRules.logger
    end
  end
end
