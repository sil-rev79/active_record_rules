# Introduction to ActiveRecordRules

## The big idea

Many business rules are written, and thought about, as "when this condition holds, take this action". A production system is a way of pattern matching over a database of facts to express these sorts of rules. For our purposes, the database of "facts" is the set of records modelled by our ActiveRecord models.

For example, expressing a rule like "for orders over $100, shipping is free" might look like this:

```ruby
define_rule("free shipping over $100") do
  after_save(<<~MATCH)
    Order(<id>)
    <order_value> = sum(<cost> * <number>) {
      OrderItem(order_id = <id>, <item_id>, <number>)
      Item(id = <item_id>, value = <cost>)
    }
    <order_value> > 100
  MATCH
  on_match do
    Order.find(id).update!(free_shipping: true)
  end
  on_unmatch do
    Order.find(id).update!(free_shipping: false)
  end
end
```

Writing production rules allows you to separate your business logic from your models, and makes it easy to match complex states involving multiple models.

## What is a production rule?

A production rule consists of two parts:

1. a pattern to match; and
2. code to run when the matched set changes.

## When do rules trigger?

Rules can be triggered in four ways:
- `after_save`: in an `after_save` callback
- `after_commit`: after ActiveRecord commits a transaction
- `after_request`: at the end of the nearest `ActiveRecordRules.wrap_request` active block - if no such block is active then this behaves the same as `after_commit`
- `later`: in an ActiveJob task, asynchronously

A rule specifies which trigger timing it uses when it declares its match conditions.

## How is state stored?

Rule state is stored in `ActiveRecordRules::RuleMatch` records. There are a few ways to find relevant match records:

1. You can pass a model instance to `ActiveRecordRules::Rule#rule_matches_for` to find all matches that are affected by a given record.
2. `ActiveRecordRules.stuck_matches` will return matches which have been queued for a long time (default: 10 minutes)
3. `ActiveRecordRules.queued_matches` will return matches which have been running for a long time (default: 10 minutes)
4. `ActiveRecordRules.failed_matches` will return matches where execution failed (i.e. raised an error)
5. `ActiveRecordRules.defunct_matches` will return matches for which there is no rule loaded (i.e. the rule that required them has been removed from the system)
