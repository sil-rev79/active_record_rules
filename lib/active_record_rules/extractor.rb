# frozen_string_literal: true

module ActiveRecordRules
  # A step to extract values out of matched objects. Memory records
  # are stored to avoid re-triggering rules if the extracted fields
  # have not changed.
  class Extractor < ActiveRecord::Base
    self.table_name = :arr__extractors

    belongs_to :condition
    belongs_to :rule

    has_many :condition_matches, through: :condition
    validates :key, uniqueness: { scope: :rule }

    # def activate(objects)
    #   id_to_values = objects.to_h do |object|
    #     [object.id, fields["names"].to_h { [_1, object[_1]] }]
    #   end

    #   extractor_matches.insert_all!(
    #     id_to_values.map do |object_id, values|
    #       { entry_id: object_id, stored_values: values }
    #     end
    #   )

    #   objects.each do |object|
    #     logger&.info { "Extractor(#{id}): matched for #{object.class}(#{object.id})" }
    #     logger&.debug { "Extractor(#{id}): matched with values #{id_to_values[object.id]}" }
    #   end

    #   extractor_keys.each { _1.activate(id_to_values.keys) }
    # end

    # def update(objects)
    #   records = extractor_matches.where(entry_id: objects.pluck(:id)).pluck(:entry_id, :stored_values).to_h

    #   new_objects = {}
    #   old_objects = {}

    #   objects.each do |object|
    #     values = fields["names"].to_h { [_1, object[_1]] }
    #     old_values = records[object.id]
    #     if old_values == values
    #       logger&.debug { "Extractor(#{id}): not updated for #{object.class}(#{object.id}) - no changes detected" }
    #       next
    #     end

    #     new_objects[object.id] = values
    #     old_objects[object.id] = old_values

    #     logger&.info { "Extractor(#{id}): updated for #{object.class}(#{object.id})" }
    #     logger&.debug do
    #       "Extractor(#{id}): updated for #{new_objects[object.id]} (previously: #{old_objects[object.id]})"
    #     end
    #   end

    #   # Bail out early if no objects actually got updated
    #   return if new_objects.empty?

    #   extractor_matches.upsert_all(
    #     new_objects.map do |id, values|
    #       { entry_id: id, stored_values: values, previous_stored_values: old_objects[id] }
    #     end,
    #     # I'm not entirely sure why we need this. The documentation
    #     # says this is SQLite and Postgres only, so I'd like to remove
    #     # it, but without this the unique index on the table isn't
    #     # honoured, so we get exceptions.
    #     unique_by: [:extractor_id, :entry_id]
    #   )

    #   extractor_keys.each { _1.update(new_objects.keys) }

    #   # Clear out the "previous stored values", because now they
    #   # should be in the rule matches that need them.
    #   extractor_matches.where.not(previous_stored_values: nil).update_all(previous_stored_values: nil)
    # end

    # def deactivate(objects)
    #   objects.each do |object|
    #     logger&.debug do
    #       "Extractor(#{id}): unmatched for #{object.class}(#{object.id}) (condition no longer matches)"
    #     end
    #   end
    #   extractor_keys.each { _1.deactivate(objects.pluck(:id)) }

    #   extractor_matches.delete_by(entry_id: objects.pluck(:id))
    # end

    private

    def logger
      ActiveRecordRules.logger
    end
  end
end
