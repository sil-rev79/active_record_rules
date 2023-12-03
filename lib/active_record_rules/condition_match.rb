# frozen_string_literal: true

module ActiveRecordRules
  # A record indicating an entry that meets a condition.
  class ConditionMatch < ActiveRecord::Base
    self.table_name = :arr__condition_matches

    belongs_to :condition
  end
end
