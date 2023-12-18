# frozen_string_literal: true

module ActiveRecordRules
  # A join between Extractors and Rules. This provides a key to the
  # extracted values so they can be referenced unambiguously in parsed
  # rule constraints. These keys are not currently user-visible, and
  # cannot be referenced explicitly in rule definitions.
  class ExtractorKey < ActiveRecord::Base
    self.table_name = :arr__extractor_keys

    belongs_to :extractor
    has_many :extractor_matches, through: :extractor
    belongs_to :rule
    validates :key, uniqueness: { scope: :rule }

    def activate(objects)
      rule.activate(key, objects)
    end

    def update(old_objects, new_objects)
      rule.update(key, old_objects, new_objects)
    end

    def deactivate(objects)
      rule.deactivate(key, objects)
    end

    private

    def logger
      ActiveRecordRules.logger
    end
  end
end
