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

    def activate(object_ids)
      rule.activate(key, object_ids)
    end

    def update(object_ids)
      rule.update(key, object_ids)
    end

    def deactivate(object_ids)
      rule.deactivate(key, object_ids)
    end
  end
end
