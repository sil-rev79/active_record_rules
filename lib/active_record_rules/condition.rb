# frozen_string_literal: true

module ActiveRecordRules
  # A simple condition which matches records by basic attribute. These
  # records are used as the entry point to the matching system.
  #
  # A single condition may be shared between multiple rules, through
  # different Extractor records. Similarly, a single rule may have
  # multiple conditions. A typical example might look like this:
  #
  #  +---------------+  +----------------- -+
  #  | [Condition]   |  | [Condition]       |
  #  | class=User    |  | class=Post        |
  #  | status=active |  | status=published  |
  #  +---------+-----+  +----+--------------+
  #            |             |
  #            v             v
  #  +---------------+  +-------------------+
  #  | [Extractor]   |  | [Extractor]       |
  #  | key=cond1     |  | key=cond2         |
  #  | fields=[id]   |  | fields=[author_id]|
  #  +---------+-----+  +----+--------------+
  #            |             |
  #            v             v
  #  +-------------------------------------+
  #  | [Rule]                              |
  #  | cond1.id = cond2.author_id          |
  #  | on_match: decrement post count      |
  #  | on_unmatch: increment post count    |
  #  +-------------------------------------+
  #
  class Condition < ActiveRecord::Base
    self.table_name = :arr__conditions

    has_many :extractors, dependent: :destroy
    has_many :condition_matches, dependent: :delete_all
    validates :match_class_name, presence: true
    validate :validate_record_class

    scope :for_class, lambda { |c|
      where(match_class_name: c.ancestors.select { _1 < ActiveRecord::Base }.map(&:name))
    }
    scope :includes_for_activate, -> { includes(extractors: { extractor_keys: { rule: { extractor_keys: {} } } }) }

    def activate(ids: nil, trigger_rules: true, batch_size: ActiveRecordRules.default_batch_size)
      deactivating_matches(ids).select(:id, :entry_id).in_batches(of: batch_size) do |matches|
        object_ids = matches.pluck(:entry_id)
        logger&.info { "Condition(#{id}): unmatched for #{match_class}(#{object_ids.join(", ")})" }
        condition_matches.delete_by(entry_id: object_ids)
        extractors.each do |extractor|
          extractor.deactivate(object_ids.map { match_class.new(id: _1) }, trigger_rules: trigger_rules)
        end
      end

      interesting_fields = extractor_fields + ["id"]

      updating_objects(ids).select(*interesting_fields).in_batches(of: batch_size) do |objects|
        logger&.info { "Condition(#{id}): matched by #{match_class}(#{objects.pluck(:id).join(", ")}) (updated)" }
        extractors.each { _1.update(objects, trigger_rules: trigger_rules) }
      end

      activating_objects(ids).select(*interesting_fields).in_batches(of: batch_size) do |objects|
        logger&.info { "Condition(#{id}): matched by #{match_class}(#{objects.pluck(:id).join(", ")}) (matched)" }
        extractors.each { _1.activate(objects) }
        condition_matches.insert_all!(objects.map { { entry_id: _1.id } })
      end

      nil
    end

    private

    def all_matching_objects
      clauses.reduce(match_class.all) do |relation, clause|
        relation.where(clause_arel(clause))
      end
    end

    def activating_objects(ids)
      all_matching_objects.where.not(id: condition_matches.select("entry_id")).where({ id: ids }.compact)
    end

    def updating_objects(ids)
      all_matching_objects.where(id: condition_matches.select("entry_id")).where({ id: ids }.compact)
    end

    def deactivating_matches(ids)
      condition_matches.where.not(entry_id: all_matching_objects.select("id")).where({ entry_id: ids }.compact)
    end

    def extractor_fields
      extractors.pluck(:fields).map { _1["names"] }.map(&:to_set).reduce(&:+)
    end

    def clauses
      @clauses ||= match_conditions["clauses"].map { Clause.parse(_1) }
    end

    def clause_arel(clause)
      clause.to_arel(match_class.arel_table, {})
    end

    def logger
      ActiveRecordRules.logger
    end

    def match_class
      match_class_name.constantize
    end

    def validate_record_class
      return if match_class < ActiveRecord::Base

      errors.add(:match_class_name,
                 "must be a subclass of ActiveRecord::Base")
    end
  end
end
