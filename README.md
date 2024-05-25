# ActiveRecordRules [![builds.sr.ht status](https://builds.sr.ht/~czan/active_record_rules.svg)](https://builds.sr.ht/~czan/active_record_rules)

A [production system][] within ActiveRecord to execute code when matching rule conditions.

[production system]: https://en.wikipedia.org/wiki/Production_system_(computer_science)

## Installation

Include `active_record_rules` in your `Gemfile`, then run the following code to generate migrations and initialisation code for `ActiveRecordRules`.

```shell
rails generate active_record_rules:install
rails db:migrate
```

Once you have done this, you need to decide on how you will *trigger* rules that are evaluated. The simplest way to do this is to add some callbacks to your `ApplicationRecord` class. This will resolve rules within the same transaction as the create/update/destroy operation. This is the simplest way to get started, but it has some pretty substantial drawbacks. See the [Triggering rules](#triggering-rules) below for more information.

```ruby
class ApplicationRecord < ActiveRecord::Base
  after_create { ActiveRecordRules.after_create_trigger(self) }
  after_update { ActiveRecordRules.after_update_trigger(self) }
  after_destroy { ActiveRecordRules.after_destroy_trigger(self) }
end
```

At the moment only Postgres and SQLite are supported. Contributions are welcome to add support for other database engines.

## Usage

### Defining rules

With the default Rails configuration you can define rules in any file with the `.rules` extension. These rules will be loaded when your Rails application starts. The rules use a custom DSL that looks like this:

```ruby
rule Apply a 10% discount to pending orders above $100 (ignoring sale items), for VIP users
  Order(id = <order_id>, <user_id>, status = "pending")
  User(id = <user_id>, vip_user = 1)
  <order_value> = sum(<value> * <quantity>) {
    OrderItem(<order_id>, <item_id>, <quantity>, <value>)
    Item(id = <item_id>, sale_discount = 0)
  }
  <order_value> > 100
on match
  Order.find(order_id).update!(discount: 0.1)
on unmatch
  order = Order.find(order_id)
  # If the order has been completed, then we don't touch it any more
  order.update!(discount: 0) unless order.status == "completed"
```

Rule executions are remembered by record id and variable bindings, so each rule will match once per set of matching objects, then won't match again for those objects until a relevant value changes. In the rule above, adding or removing an item from an order will automatically re-run the `match` code.

There are three types of clauses that can be run on updates:
 - `on match`: when the rule matches a new set of records.
 - `on update`: when the rule matches the same set of records (by id), but with different bound values. If this is not provided then updates are treated as an unmatch then a match.
 - `on unmatch`: when the rule no longer matches a set of records.

Note that `on update` blocks must use `.old` and `.new` to access the last-seen and current values.

### Triggering rules

In order to make the rules effective, they need to be provided with records to match. There are many trade-offs involved in deciding the best moment to evaluate rule matches, so it's hard for a library to make the right decision for your application.

Rule evaluation happens in three stages:
 1. *triggering*: taking a change to an object (represented by a `(class, attributes_before, attributes_after)` triple) and determining which rules need to be activated, and for which ids; then
 2. *activating*: for each relevant rule, determine the new matching state (i.e. which records newly match/unmatch, or have been updated in a relevant way) and record which clauses need to be executed; then
 3. *executing*: run the code for each clause which needs to be executed.

Invoking these stages is done by calling three methods:

```ruby
# These methods capture information about a change, to run a trigger later.
# They are each suitable to run in the given ActiveRecord callback.
change = ActiveRecordRules.capture_create_change(self)
change = ActiveRecordRules.capture_update_change(self)
change = ActiveRecordRules.capture_destroy_change(self)

# Trigger and activate rules, for a given change, marking relevant rule-match
# database records as "pending execution" and returning the ids of those records
ids = ActiveRecordRules.activate_rules(change)

# Process a number of pending executions
ActiveRecordRules.run_pending_executions(*ids)
```

The helper methods used above, `ActiveRecordRules.after_{create,update,destroy}_trigger` run these methods in sequence to provide a simple way to get things working. In a production system, though, you might prefer to process rules in a separate thread/process. For example, using `ActiveJob` you might have:

```ruby
class ApplicationRecord < ActiveRecord::Base
  after_create { ActivateRules.perform_later(ActiveRecordRules.capture_create_change(self)) }
  after_update { ActivateRules.perform_later(ActiveRecordRules.capture_update_change(self)) }
  after_destroy { ActivateRules.perform_later(ActiveRecordRules.capture_destroy_change(self)) }
end

class ActivateRules < ApplicationJob
  def perform(change)
    ids = ActiveRecordRules.activate_rules(change)
    ids.each { RunPendingExecutions.perform_later(_1) }
  end
end

class RunPendingExecutions < ApplicationJob
  def perform(id)
    ActiveRecordRules.run_pending_execution(id)
  end
end
```

## Development

This project uses Guix as its main dependency management system. A development environment can be created by running:

```sh
guix shell --development --file=guix.scm
```

## Contributing

Bug reports and changes are welcome on SourceHut at <https://sr.ht/~czan/active_record_rules/>.
