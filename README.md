# ActiveRecordRules [![builds.sr.ht status](https://builds.sr.ht/~czan/active_record_rules.svg)](https://builds.sr.ht/~czan/active_record_rules)

A [production system][] within ActiveRecord to execute code when matching rule conditions.

[production system]: https://en.wikipedia.org/wiki/Production_system_(computer_science)

## Installation

Include `active_record_rules` in your `Gemfile`, then run the following code to generate migrations and initialisation code for `ActiveRecordRules`.

```shell
rails generate active_record_rules:install postgres # or sqlite
rails db:migrate
```

Once you have done this, you need to decide on how you will *trigger* rules that are evaluated. The simplest way to do this is to add a callback to your `ApplicationRecord` class. See the [Triggering rules][#triggering-rules] below for more information.

```ruby
class ApplicationRecord < ActiveRecord::Base
  after_commit { ActiveRecordRules.trigger([self]) }
end
```

At the moment only Postgres and SQLite are supported. Contributions are welcome to add support for other database engines.

## Usage

### Defining rules

With the default Rails configuration you can define rules in any file with the `.rules` extension. These rules will be loaded every time `db:migrate` or `db:schema:load` is run. The rules use a custom DSL that looks like this:

```ruby
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
```

Rule executions are remembered by record id and variable bindings, so each rule will match once per set of matching objects, then won't match again for those objects until an attribute referenced in the rules changes. In the rule above, editing a post's content within five minutes of creation wouldn't trigger a new match, but editing the post's title would.

There are three types of clauses that can be run on updates:
 - `on match`: when the rule matches a new set of records.
 - `on update`: when the rule matches the same set of records (by id), but with different bound values - if not provided then updates are treated as an unmatch then a match.
 - `on unmatch`: when the rule no longer matches a set of records.

An example of `on unmatch`:

```ruby
rule Update number of posts for user
  Post(<author_id>, status = "published")
  User(id = <author_id>)
on match
  User.find(author_id).increment!(:post_count)
on unmatch
  User.find(author_id).decrement!(:post_count)
```

This rule will match when a post is put in the `published` state, and unmatch when it is removed from the `published` state.

An example of `on update`:

```ruby
rule Keep summary records for posts with their users
  Post(id = <post_id>, <author_id>, <title>)
  User(id = <author_id>, <name>)
on match
  Publication.create!(post_title: title, author_name: name)
on update
  Publication
    .find_by(post_title: title.old, author_name: name.old)
    .update!(post_title: title.new, author_name: name.new)
on unmatch
  Publication.destroy!(post_title: title, author_name: name)
```

Note that `on update` blocks must use `.old` and `.new` to access the last-seen and current values.

### Triggering rules

In order to make the rules effective, they need to be provided with records to match. There are many trade-offs involved in deciding the best moment to evaluate rule matches, so it's hard for a library to make the right decision for your application.

Rules are triggered by calling the `ActiveRecordRules.trigger` method, and passing it an array of model instances. You can also trigger *all records* of given classes by using `ActiveRecordRules.trigger_all(c1, c2, ...)`. Invoking `trigger_all` with no arguments will trigger *all records* of *all classes*.

#### Batch triggering

The best way to trigger rules is in batches. Determining what a "batch" consists of is application-dependent. One option is to define an async job, and use a Redis set to accumulate entries:

```ruby
class TriggerRulesJob < ApplicationJob
  queue_as :default

  def perform
    items = Redis.spop('awaiting_rules_triggering')
    return if items.empty?

    ActiveRecordRules.trigger(items.map { _1.constantize.new(_2) })
  end
end
```

Then write to the set and trigger the job with an ActiveRecord callback:

```ruby
class ApplicationRecord < ActiveRecord::Base
  after_commit do
    Redis.sadd('awaiting_rules_triggering')
    TriggerRulesJob.perform_async
  end
end
```

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
