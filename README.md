# ActiveRecordRules [![builds.sr.ht status](https://builds.sr.ht/~czan/active_record_rules.svg)](https://builds.sr.ht/~czan/active_record_rules)

A [production system][] within ActiveRecord to execute code when matching rule conditions.

[production system]: https://en.wikipedia.org/wiki/Production_system_(computer_science)

## Installation

Include `active_record_rules` in your `Gemfile`, then run:

```shell
rails generate active_record_rules:install postgres # or sqlite
rails db:migrate
```

This will install and run the necessary migrations to `db/migrate` to store rule matching information. This will also install a Rails configuration file to set the SQL dialect to use.

At the moment only Postgres and SQLite are supported. Contributions are welcome to add support for other database engines.

## Usage

### Defining rules

You can define rules using an embedded DSL, like this:

```ruby
ActiveRecordRules.define_rule(<<~RULE)
  rule Email users when new post is created
    Post(id = <post_id>, <title>, <created_at>)
    User(id = <user_id>, <name>, <email>)
    PostTag(<post_id>, <tag_id>)
    TagSubscription(<user_id>, <tag_id>)
  on match
    # This is just Ruby code
    if created_at > 5.minutes.ago                 # if the post is new
      PostNotifier.send_email(name, email, title) # notify the users
    end
RULE
```

Rule executions are remembered by record id and variable bindings, so each rule will match once per set of matching objects, then won't match again for those objects until an attribute referenced in the rules changes. In the rule above, editing a post's content within five minutes of creation wouldn't trigger a new match, but editing the post's title would.

It's also possible to perform some action when a rule ceases to match. This can be done by adding an `on unmatch` section:

```ruby
ActiveRecordRules.define_rule(<<~RULE)
  rule Update number of posts for user
    Post(<author_id>, status = "published")
    User(id = <author_id>)
  on match
    User.find(author_id).increment!(:post_count)
  on unmatch
    User.find(author_id).decrement!(:post_count)
RULE
```

This rule will match when a post is put in the `published` state, and unmatch when it is removed from the `published` state.

### Triggering rules

In order to make the rules effective, they need to be provided with records to match. There are many trade-offs involved in deciding the best moment to evaluate rule matches, so it's hard for a library to make the right decision for your application.

Rules are triggered by calling the `ActiveRecordRules.trigger` method, and passing it an array of model instances.

#### Batch triggering

The best way to trigger rules is in batches. The best way to do this isn't yet established, so you might need to figure it out yourself for now. This section will be updated as we learn more.

#### After save

```ruby
class ApplicationRecord < ActiveRecord::Base
  after_save -> { ActiveRecordRules.trigger([self]) }
  after_destroy -> { ActiveRecordRules.trigger([self]) }
end
```

Triggering rules after saving performs the rule matching within the same database transaction, which keeps the rule state in sync with the record state at all times. The biggest downside of this approach is performance. Rule matching does several database queries, and it might not be obvious which rules will be triggered by any given save.

#### After commit

```ruby
class ApplicationRecord < ActiveRecord::Base
  after_commit -> { ActiveRecordRules.trigger([self]) }
end
```

Triggering rules after commit performs rule matching in a separate database transaction. This means that the rules state and the database state will have a period where they are out of sync, but will quickly converge. This has the same downside as using `after_save`, but it has smaller transactions.

## Development

This project uses Guix as its main dependency management system. A development environment can be created by running:

```sh
guix shell --development --file=guix.scm
```

## Contributing

Bug reports and changes are welcome on SourceHut at <https://sr.ht/~czan/active_record_rules/>.
