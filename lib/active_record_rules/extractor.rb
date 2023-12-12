# frozen_string_literal: true

module ActiveRecordRules
  # A join between Condition and Rules. Each Extractor also has a
  # key which is used to refer to the objects matching it when rule
  # constraints are checked.
  #
  # Extractor performs two functions:
  #
  #  1. associate the condition with a name, so they can be referenced
  #     in Rule constraints
  #
  #  2. store the relevant fields (in ExtractorMatch objects) to avoid
  #     triggering rules on irreleveant updates
  class Extractor < ActiveRecord::Base
    self.table_name = :arr__extractors

    belongs_to :condition
    has_many :extractor_matches, dependent: :destroy
    belongs_to :rule
    validates :key, uniqueness: { scope: :rule }

    def activate(object)
      values = fields.to_h { [_1, object[_1]] }

      if (match = extractor_matches.find_by(entry_id: object.id))
        old_values = match.values
        match.update!(values: values)

        logger&.info { "Extractor(#{id}): updated for #{object.class}(#{object.id})" }
        logger&.debug { "Extractor(#{id}): updated for #{values} (previously: #{old_values})" }
        rule.update(key, object, old_values, values) unless old_values == values
      else
        logger&.info { "Extractor(#{id}): matched for #{object.class}(#{object.id})" }
        logger&.debug { "Extractor(#{id}): matched with values #{values}" }
        extractor_matches.create!(
          entry_id: object.id,
          values: values
        )

        rule.activate(key, object, values)
      end
    end

    def deactivate(object)
      extractor_matches.destroy_by(entry_id: object.id)&.each do |match|
        logger&.debug do
          "Extractor(#{id}): unmatched for #{object.class}(#{object.id}) (condition no longer matches)"
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
