# frozen_string_literal: true

require "active_record_rules/condition"
require "active_record_rules/condition_activation"
require "active_record_rules/condition_rule"
require "active_record_rules/fact"
require "active_record_rules/parser"
require "active_record_rules/rule"
require "active_record_rules/rule_activation"

# A production rule system for ActiveRecord objects.
#
# To use this system, include +ActiveRecordRules::Fact+ in the models
# that you would like to use in your rules, then define rules to match
# them.
#
# @example Define a simple rule
#   class Post < ApplicationRecord; include ActiveRecordRules::Fact; end
#   class User < ApplicationRecord; include ActiveRecordRules::Fact; end
#
#   ActiveRecordRules.define_rule(<<~RULE)
#     rule Update number of posts for user
#       Post(author_id, status = "published")
#       User(id = author_id)
#     on activation
#       User.find(author_id).increment!(:post_count)
#     on deactivation
#       User.find(author_id).decrement!(:post_count)
#   RULE
#
# Rules are persisted as database values (see
# ActiveRecordRules::Rule), and can be modified as part of a running
# system.
module ActiveRecordRules
  cattr_accessor :logger

  def self.define_rule(string)
    ActiveRecordRules::Rule.define_rule(string)
  end

  def self.trigger_rule_updates(object)
    Condition
      .for_object(object)
      .includes_for_activate
      .each { _1.activate(object) }
  end
end
