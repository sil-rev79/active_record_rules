class ApplicationRecord < ActiveRecord::Base
  include ActiveRecordRules::Hooks

  primary_abstract_class
end
