# frozen_string_literal: true

module ActiveRecordRules
  # A record indicating an entry that meets a condition/rule combo.
  class ExtractorMatch < ActiveRecord::Base
    self.table_name = :arr__extractor_matches

    belongs_to :extractor
  end
end
