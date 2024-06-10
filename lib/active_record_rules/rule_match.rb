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
  end
end
