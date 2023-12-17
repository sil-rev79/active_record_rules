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

    has_many :extractors
    has_many :condition_matches
    validates :match_class_name, presence: true
    validate :validate_record_class

    scope :for_class, lambda { |c|
      where(match_class_name: c.ancestors.select { _1 < ActiveRecord::Base }.map(&:name))
    }
    scope :includes_for_activate, -> { includes(extractors: { rule: { extractors: {} } }) }

    def activate_all
      all_matching_objects = clauses.reduce(match_class.all) do |relation, clause|
        relation.where(clause_arel(clause))
      end

      updating = condition_matches.where(entry_id: all_matching_objects).pluck(:id).to_set
      updating, activating = all_matching_objects.partition { updating.include?(_1.id) }

      all_ids_arel = match_class.all.arel.tap do |arel|
        arel.projections = [match_class.arel_table[:id]]
      end
      deactivating = condition_matches
                     .where.not(entry_id: all_matching_objects)
                     .where(entry_id: match_class.all)
                     .pluck(:entry_id, ConditionMatch.arel_table[:entry_id].in(all_ids_arel))
                     .map { [match_class.new(id: _1), _2] }

      activating.each do |object|
        logger&.info { "Condition(#{id}): matched by #{object.class}(#{object.id}) (matched)" }
      end
      extractors.each { _1.activate(activating) } unless activating.empty?

      updating.each do |object|
        logger&.info { "Condition(#{id}): matched by #{object.class}(#{object.id}) (updated)" }
      end
      extractors.each { _1.update(updating) } unless updating.empty?

      deactivating.each do |object, still_exists|
        logger&.info do
          if still_exists
            "Condition(#{id}): unmatched for #{object.class}(#{object.id}) (ceased to match)"
          else
            "Condition(#{id}): unmatched for #{object.class}(#{object.id}) (deleted)"
          end
        end
      end
      extractors.each { _1.deactivate(deactivating.map(&:first)) } unless deactivating.empty?

      nil
    end

    def activate(objects)
      unless objects.all? { match_class_name == _1.class.name }
        raise "Objects must all be of class #{match_class_name}, but saw #{objects.map(&:class).uniq.join(", ")}"
      end

      # First, do the basic matching to work out which objects match,
      # and which ones don't. This basically requires us to go object
      # by object, but it's all in-memory and constant.
      matching_objects, non_matching_objects = objects.partition do |object|
        logger&.debug { "Condition(#{id}): checking #{object.class}(#{object.id})" }
        object.persisted? && clauses.all? { matches_clause?(_1, object) }
      end

      # For the matching objects, we need to further divide them into
      # "activating" (i.e. newly matching) and "updating". This
      # requires two database queries: one to fetch the existing
      # records, and then one to insert the new records.
      updated_ids = condition_matches.where(entry_id: matching_objects).pluck(:entry_id).to_set
      updating_objects, activating_objects = matching_objects.partition { updated_ids.include?(_1.id) }
      condition_matches.insert_all!(activating_objects.map { { entry_id: _1.id } }) if activating_objects.any?

      # For the non-matching objects, we need to further divide them
      # into "deactivating" (i.e. newly non-matching) and "never
      # matched" records. This also requires two database queries: one
      # to find the ids of existing records, and the other to delete
      # them.
      deactivating_ids = condition_matches.where(entry_id: non_matching_objects).pluck(:entry_id).to_set
      condition_matches.delete_by(entry_id: deactivating_ids) if deactivating_ids.any?
      deactivating_objects, never_matched_objects = non_matching_objects.partition { deactivating_ids.include?(_1.id) }

      # By this point, we have updated the database's record of our
      # matches, and we've separated our objects into four categories:
      # "activating", "updating", "deactivating", and "never
      # matched". Now we need to log that information, and pass these
      # objects on to any relevant extractors.

      activating_objects.each do |object|
        logger&.info { "Condition(#{id}): matched by #{object.class}(#{object.id}) (matched)" }
      end
      extractors.each { _1.activate(activating_objects) } unless activating_objects.empty?

      updating_objects.each do |object|
        logger&.info { "Condition(#{id}): matched by #{object.class}(#{object.id}) (updated)" }
      end
      extractors.each { _1.update(updating_objects) } unless updating_objects.empty?

      deactivating_objects.each do |object|
        logger&.info do
          if object.persisted?
            "Condition(#{id}): unmatched for #{object.class}(#{object.id}) (ceased to match)"
          else
            "Condition(#{id}): unmatched for #{object.class}(#{object.id}) (deleted)"
          end
        end
      end
      extractors.each { _1.deactivate(deactivating_objects) } unless deactivating_objects.empty?

      # Never matched objects don't actually do anything, but we debug
      # long them in case it's useful.
      never_matched_objects.each do |object|
        logger&.debug do
          "Condition(#{id}): not matched for #{object.class}(#{object.id}) (never matched)"
        end
      end

      # Explicitly return no useful value.
      nil
    end

    private

    def clauses
      @clauses ||= begin
        parser = Parser.new.condition_part
        match_conditions["clauses"].map do |text|
          { parsed: parser.parse(text),
            text: text }
        end
      end
    end

    def matches_clause?(clause, object)
      lhs, op, rhs = case clause[:parsed]
                     in { name:, op:, rhs: { string: } }
                       [object[name], (op == "=" ? "==" : op), string.to_s]
                     in { name:, op:, rhs: { number: } }
                       [object[name], (op == "=" ? "==" : op), number.to_i]
                     in { name:, op:, rhs: { boolean: } }
                       [object[name], (op == "=" ? "==" : op), (boolean.to_s == "true")]
                     in { name:, op:, rhs: { nil: _ } }
                       [object[name], (op == "=" ? "==" : op), nil]
                     else
                       raise "Non-constant test in Condition(#{id}): #{clause[:text]}"
                     end
      result = lhs.public_send(op, rhs)
      logger&.debug do
        if result
          "Condition(#{id}): #{lhs.inspect} #{op} #{rhs.inspect} (#{clause[:text]}) matches"
        else
          "Condition(#{id}): #{lhs.inspect} #{op} #{rhs.inspect} (#{clause[:text]}) does not match"
        end
      end
      result
    end

    def clause_arel(clause)
      table = match_class.arel_table
      op_method = { "=" => :eq, "!=" => :neq, "<" => :lt, "<=" => :lte, ">" => :gt, ">=" => :gte }
      lhs, op, rhs = case clause[:parsed]
                     in { name:, op:, rhs: { string: } }
                       [table[name], op_method[op.to_s], string.to_s]
                     in { name:, op:, rhs: { number: } }
                       [table[name], op_method[op.to_s], number.to_i]
                     in { name:, op:, rhs: { boolean: } }
                       [table[name], op_method[op.to_s], (boolean.to_s == "true")]
                     in { name:, op:, rhs: { nil: _ } }
                       [table[name], op_method[op.to_s], Arel.sql("null")]
                     else
                       raise "Non-constant test in Condition(#{id}): #{clause[:text]}"
                     end
      lhs.public_send(op, rhs)
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
