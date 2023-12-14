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

    def activate(objects)
      extractor_matches.insert_all!(
        objects.map do |object|
          { entry_id: object.id,
            values: fields.to_h { [_1, object[_1]] } }
        end
      )

      objects.map do |object|
        values = fields.to_h { [_1, object[_1]] }

        logger&.info { "Extractor(#{id}): matched for #{object.class}(#{object.id})" }
        logger&.debug { "Extractor(#{id}): matched with values #{values}" }
        rule.activate(key, object, values)
      end
    end

    def update(objects)
      records = extractor_matches.where(entry_id: objects.pluck(:id)).pluck(:entry_id, :values).to_h
      extractor_matches.upsert_all(
        objects.map do |object|
          { entry_id: object.id,
            values: fields.to_h { [_1, object[_1]] } }
        end,
        # I'm not entirely sure why we need this. The documentation
        # says this is SQLite and Postgres only, so I'd like to remove
        # it, but without this the unique index on the table isn't
        # honoured, so we get exceptions.
        unique_by: [:extractor_id, :entry_id]
      )

      objects.map do |object|
        old_values = records[object.id]
        values = fields.to_h { [_1, object[_1]] }

        logger&.info { "Extractor(#{id}): updated for #{object.class}(#{object.id})" }
        logger&.debug { "Extractor(#{id}): updated for #{values} (previously: #{old_values})" }
        if old_values.nil?
          logger&.warn do
            "Extractor(#{id}): matched for #{object.class}(#{object.id}) during update - unexpected database state!"
          end
          rule.activate(key, object, values)
        else
          rule.update(key, object, old_values, values)
        end
      end
    end

    def deactivate(objects)
      records = extractor_matches.where(entry_id: objects.pluck(:id)).pluck(:entry_id, :values).to_h
      if records.size < objects.size
        logger&.warn do
          "Extractor(#{id}): unexpected number of deactivations - #{records.size} found, #{objects.size} expected"
        end
      end

      extractor_matches.delete_by(entry_id: records.keys)

      objects.each do |object|
        logger&.debug do
          "Extractor(#{id}): unmatched for #{object.class}(#{object.id}) (condition no longer matches)"
        end
        rule.deactivate(key, object, records[object.id])
      end
    end

    private

    def logger
      ActiveRecordRules.logger
    end
  end
end
