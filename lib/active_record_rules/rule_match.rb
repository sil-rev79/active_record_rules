# frozen_string_literal: true

module ActiveRecordRules
  # A record to remember which values a rule has already fired
  # for.
  #
  # This stores two main values:
  #
  #  - ids: The ids of the objects that were matched. This is used to
  #    prevent reactivating the rule for the same underlying objects.
  #
  #  - arguments: The arguments that the activation code was called
  #    with. This is primarily used to ensure that deactivation code
  #    is called with the same values as the activation code was. The
  #    arguments are also used to detect when a rule needs to be
  #    "updated" (i.e. deactivated and immediately reactivated with
  #    new values).
  class RuleMatch < ActiveRecord::Base
    self.table_name = :arr__rule_matches

    def deconstruct_keys(_)
      { id: id,
        rule_id: rule_id,
        ids: ids,
        live_arguments: live_arguments,
        next_arguments: next_arguments }
    end

    def rule
      @rule ||=
        ActiveRecordRules.find_rule(rule_id) or
        raise "Cannot find loaded rule for match #{id} (rule id: #{rule_id})"
    end

    # @return [Boolean] whether this match has further pending executions
    def execute!
      case self
      in RuleMatch(live_arguments: nil, next_arguments: nil)
        delete
        false # does not need execution

      in RuleMatch(ids:, live_arguments:, next_arguments: nil)
        logger&.info { "Rule(#{rule_id}): unmatched for #{ids.to_json}" }
        logger&.debug { "Rule(#{rule_id}): unmatched with arguments #{live_arguments.to_json}" }

        begin
          rule.execute_unmatch(live_arguments)
        rescue StandardError => e
          ActiveRecord::Base.connection.execute(<<~SQL.squish!)
            update #{RuleMatch.table_name}
               set failed_since = coalesce(failed_since, current_timestamp)
             where id = #{ActiveRecord::Base.connection.quote(id)}
          SQL
          raise e
        end

        ActiveRecord::Base.connection.execute(<<~SQL.squish!).pluck("needs_execution").any?
          update #{RuleMatch.table_name}
             set running_since = null,
                 failed_since = null,
                 live_arguments = null
           where id = #{ActiveRecord::Base.connection.quote(id)}
           returning (queued_since is not null) as needs_execution
        SQL

      in RuleMatch(ids:, live_arguments: nil, next_arguments:)
        logger&.info { "Rule(#{rule_id}): matched for #{ids.to_json}" }
        logger&.debug { "Rule(#{rule_id}): matched with arguments #{next_arguments.to_json}" }

        begin
          rule.execute_match(next_arguments)
        rescue StandardError => e
          ActiveRecord::Base.connection.execute(<<~SQL.squish!)
            update #{RuleMatch.table_name}
               set running_since = null,
                   failed_since = coalesce(failed_since, current_timestamp)
             where id = #{ActiveRecord::Base.connection.quote(id)}
          SQL
          raise e
        end

        ActiveRecord::Base.connection.execute(<<~SQL.squish!).pluck("needs_execution").any?
          update #{RuleMatch.table_name}
             set running_since = null,
                  failed_since = null,
                 live_arguments = #{ActiveRecord::Base.connection.quote(next_arguments.to_json)},
                 next_arguments = case when next_arguments = #{ActiveRecord::Base.connection.quote(next_arguments.to_json)} then
                                    null
                                  else
                                    next_arguments
                                  end
           where id = #{ActiveRecord::Base.connection.quote(id)}
           returning (queued_since is not null) as needs_execution
        SQL

      in RuleMatch(ids:, live_arguments:, next_arguments:)
        if live_arguments == next_arguments
          logger&.info { "Rule(#{rule_id}): not executing - no change for #{ids.to_json}" }
          logger&.debug { "Rule(#{rule_id}): leaving match as #{live_arguments.to_json}" }
        else
          logger&.info { "Rule(#{rule_id}): updated for #{ids.to_json}" }
          logger&.debug do
            "Rule(#{rule_id}): updating from #{live_arguments.to_json} " \
              "=> #{next_arguments.to_json}"
          end

          begin
            rule.execute_update(live_arguments, next_arguments)
          rescue StandardError => e
            ActiveRecord::Base.connection.execute(<<~SQL.squish!)
              update #{RuleMatch.table_name}
                 set running_since = null,
                     failed_since = coalesce(failed_since, current_timestamp)
               where id = #{ActiveRecord::Base.connection.quote(id)}
            SQL
            raise e
          end
        end

        ActiveRecord::Base.connection.execute(<<~SQL.squish!).pluck("needs_execution").any?
          update #{RuleMatch.table_name}
             set running_since = null,
                 failed_since = null,
                 live_arguments = #{ActiveRecord::Base.connection.quote(next_arguments.to_json)},
                 next_arguments = case when next_arguments = #{ActiveRecord::Base.connection.quote(next_arguments.to_json)} then
                                    null
                                  else
                                    next_arguments
                                  end
           where id = #{ActiveRecord::Base.connection.quote(id)}
           returning (queued_since is not null) as needs_execution
        SQL
      end
    end

    private

    def logger
      ActiveRecordRules.logger
    end
  end
end
