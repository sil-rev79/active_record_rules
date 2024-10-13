# frozen_string_literal: true

module ActiveRecordRules
  class RuleMatchId < ActiveRecord::Base
    self.table_name = :arr__rule_match_ids

    # def deconstruct_keys(_)
    #   { id: id,
    #     rule_id: rule_id,
    #     ids: ids,
    #     live_arguments: live_arguments,
    #     next_arguments: next_arguments }
    # end
  end
end
