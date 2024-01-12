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
    scope :includes_for_activate, -> { includes(extractors: { rule: { extractors: {} } }) }

    def activate(ids: nil)
      ActiveRecord::Base.connection.execute(<<~SQL.squish)
        insert into arr__condition_matches(condition_id, entry_id, stored_values, previous_stored_values)
          select #{ActiveRecord::Base.sanitize_sql(id)},
                 coalesce(record.id, match.entry_id),
                 case when record.id is not null then
                   #{json_object_function}(#{extractor_fields.map { "'#{_1}', record.#{_1}" }.join(",")})
                 end,
                 match.stored_values
            from (#{all_matching_objects.where({ id: ids }.compact).to_sql}) as record
            full outer join
              (#{condition_matches.where({ entry_id: ids }.compact).to_sql}) as match
              on record.id = match.entry_id
           where true
          on conflict(condition_id, entry_id) do update
            set stored_values = excluded.stored_values,
                previous_stored_values = excluded.previous_stored_values
      SQL

      if logger&.debug?
        unmatched_ids = condition_matches.where({ entry_id: ids }.compact)
                                         .where("stored_values is null")
                                         .pluck(:entry_id)
        unmatched_ids.each do |entry_id|
          logger.debug("Condition(#{id}): unmatched #{match_class_name}(#{entry_id})")
        end

        # The logic here is that previous_stored_values is only null
        # for newly processed records, after the above. That is: if
        # the above query fired for an object, then
        # previous_stored_values will not be null.
        matched_ids = condition_matches.where({ entry_id: ids }.compact)
                                       .where("previous_stored_values is null")
                                       .pluck(:entry_id)
        matched_ids.each do |entry_id|
          logger.debug("Condition(#{id}): matched #{match_class_name}(#{entry_id})")
        end
      end

      return unless ids

      rules_to_activate = Hash.new do |h, k|
        h[k] = Hash.new { _1[_2] = [] }
      end

      extractors.pluck(:rule_id, :key).each do |rule_id, key|
        rules_to_activate[rule_id][key] += ids
      end

      rules_to_activate
    end

    def cleanup(ids: nil)
      ActiveRecord::Base.connection.execute(<<~SQL.squish)
        delete from arr__condition_matches
         where condition_id = #{ActiveRecord::Base.sanitize_sql(id)}
           and stored_values is null
           and #{id_clause("entry_id", ids)}
      SQL

      ActiveRecord::Base.connection.execute(<<~SQL.squish)
        update arr__condition_matches
           set previous_stored_values = null
         where condition_id = #{ActiveRecord::Base.sanitize_sql(id)}
           and #{id_clause("entry_id", ids)}
      SQL
    end

    private

    def json_object_function
      if ActiveRecordRules.dialect == :sqlite
        "json_object"
      elsif ActiveRecordRules.dialect == :postgres
        "jsonb_build_object"
      else
        raise "Unknown dialect: #{ActiveRecordRules.dialect}"
      end
    end

    def id_clause(field, ids)
      if ids
        ids_sql = ids.map { ActiveRecord::Base.sanitize_sql(_1) }.join(",")
        "#{field} in (#{ids_sql})"
      else
        "true"
      end
    end

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
      @clauses ||= match_conditions["clauses"].map { Clause.parse(_1, match_class) }
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
