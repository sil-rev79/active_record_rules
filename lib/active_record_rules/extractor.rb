# frozen_string_literal: true

module ActiveRecordRules
  # A step to extract values out of matched objects. Memory records
  # are stored to avoid re-triggering rules if the extracted fields
  # have not changed.
  class Extractor < ActiveRecord::Base
    self.table_name = :arr__extractors

    belongs_to :condition
    has_many :extractor_matches, dependent: :delete_all
    has_many :extractor_keys, dependent: :delete_all

    def activate(objects, trigger_rules: true)
      id_to_values = objects.to_h do |object|
        [object.id, fields["names"].to_h { [_1, object[_1]] }]
      end

      extractor_matches.insert_all!(
        id_to_values.map do |object_id, values|
          { entry_id: object_id, values: values }
        end
      )

      objects.each do |object|
        logger&.info { "Extractor(#{id}): matched for #{object.class}(#{object.id})" }
        logger&.debug { "Extractor(#{id}): matched with values #{id_to_values[object.id]}" }
      end

      extractor_keys.each { _1.activate(id_to_values, trigger_rules: trigger_rules) }
    end

    def update(objects, trigger_rules: true)
      records = extractor_matches.where(entry_id: objects.pluck(:id)).pluck(:entry_id, :values).to_h

      new_objects = {}
      old_objects = {}

      objects.each do |object|
        values = fields["names"].to_h { [_1, object[_1]] }
        old_values = records[object.id]
        if old_values == values
          logger&.debug { "Extractor(#{id}): not updated for #{object.class}(#{object.id}) - no changes detected" }
          next
        end

        new_objects[object.id] = values
        old_objects[object.id] = old_values
      end

      # Bail out early if no objects actually got updated
      return if new_objects.empty?

      extractor_matches.upsert_all(
        new_objects.map do |id, values|
          { entry_id: id, values: values }
        end,
        # I'm not entirely sure why we need this. The documentation
        # says this is SQLite and Postgres only, so I'd like to remove
        # it, but without this the unique index on the table isn't
        # honoured, so we get exceptions.
        unique_by: [:extractor_id, :entry_id]
      )

      objects.each do |object|
        logger&.info { "Extractor(#{id}): updated for #{object.class}(#{object.id})" }
        logger&.debug do
          "Extractor(#{id}): updated for #{new_objects[object.id]} (previously: #{old_objects[object.id]})"
        end
      end

      extractor_keys.each { _1.update(old_objects, new_objects, trigger_rules: trigger_rules) }
    end

    def deactivate(objects, trigger_rules: true)
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
      end
      extractor_keys.each { _1.deactivate(records, trigger_rules: trigger_rules) }
    end

    private

    def logger
      ActiveRecordRules.logger
    end
  end
end
