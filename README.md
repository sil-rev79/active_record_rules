# ActiveRecordRules [![builds.sr.ht status](https://builds.sr.ht/~czan/active_record_rules.svg)](https://builds.sr.ht/~czan/active_record_rules)

A [production system][] within ActiveRecord to execute code when matching rule conditions.

Rules are a great way to simplify business logic, but too often their target audience has been non-developers. Instead, ActiveRecordRules sees itself as a tool for _developers_ to express the complex logic of their system. The matching logic for rules is written in a custom DSL, but the resulting behaviours are regular Ruby code:

```
async rule Unapproved customers must be in "pending" state
  # Custom matching DSL. '<id>' denotes a variable called `id`.
  Customer(<id>, status != "pending")
  not { CustomerApproval(customer_id = <id>, status = "approved") }
on match
  # Regular Ruby code
  Customer.find(id).update!(status: 'pending')
```

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
  include ActiveRecordRules::Hooks
end
```

At the moment only Postgres and SQLite are supported. Contributions are welcome to add support for other database engines.

## Usage

### Defining rules

With the default Rails configuration you can define rules in any file with the `.rules` extension. These rules will be loaded when your Rails application starts. The rules use a custom DSL that looks like this:

```
after save rule: Apply a 10% discount to pending orders above $100 (ignoring sale items), for VIP customers
  Order(id = <order_id>, <customer_id>, status = "pending")
  Customer(id = <customer_id>, vip_customer = true)
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

Each rule declares how it will be run:
 - `after save`, i.e. in an `after_save` hook;
 - `after commit`, i.e. in an `after_commit` hook; or
 - `async`, i.e. in an `ActiveJob` that is scheduled in an `after_commit` hook.

## Rule State

The current state of matches is stored in `RuleMatch` records. As the rules themselves do not have a database presence (existing only in code), `RuleMatch` records are connected to rules by a truncated MD5 hash of the rule name. This has several important consequences for the management of rule state:

 1. **Changing the name of a rule invalidates all existing matches.** Or, put another way, renaming a rule is equivalent to deleting the rule with the old name, and adding a new rule with the new name.

 2. **Rules will only (re)match on records as they are changed, not all existing records.** This is because there is no way for ActiveRecordRules to tell the difference between the first load of a rule, or other subsequent loads. If you want to match all existing records you will have to run something like

    ```
    ids = ActiveRecordRules.find_rule(rule_name).activate
    ActiveRecordRules.run_pending_executions(ids, :all)
    ```

 3. **Updates to rule logic/code may leave inconsistencies in `update`/`unmatch` clauses.** Due to the way ActiveRecordRules persists the last-matched values for `update` and `unmatch` clauses, the variables provided to these clauses may not match those expected by the rule. Any names not present in the last-matched values will be provided as `nil`, and any binding names removed from the matching logic will not be accessible.

    ```
    # Initial definition
    async rule Example
      Record(<id>, <name>)
    on match
      pp [id, name] # available names
    on unmatch
      # both id and name are available, and will be the value from the matched record
      pp [id, name]

    # redefined to
    async rule Example
      Record(<id>, <nickname>)
    on match
      # nickname may be nil for records which activated with the old definition,
      #   but haven't been executed yet
      # name is not exposed, and cannot be used
      pp [id, nickname]
    on unmatch
      # nickname may be nil, for old matches which have "name" instead
      # name is not exposed, and cannot be used
      pp [id, nickname]
    ```

## Development

This project uses Guix as its main dependency management system. A development environment can be created by running:

```sh
guix shell --development --file=guix.scm
```

## Contributing

Bug reports and changes are welcome on SourceHut at <https://sr.ht/~czan/active_record_rules/>.
