# ActiveRecordRules

A [production system][] within ActiveRecord to execute code when matching rule conditions.

[production system]: https://en.wikipedia.org/wiki/Production_system_(computer_science)

## Installation

Include `active_record_rules` in your `Gemfile`, then run:

```shell
# "jsonb" is the most appropriate Postgres JSON type, use "json" for SQLite
# "integer" is the default Rails id type, but your application might customise this
rails generate active_record_rules:install --json_type=jsonb --id_type=integer
rails db:migrate
```

If you'd like logging, you can set `ActiveRecordRules.logger` to a logger of your choosing (e.g. `Rails.logger`). Messages about `Condition` and `Rule` matching/unmatching will be logged at `info` level, and detailed information about specific tests will be logged at `debug` level.

## Usage

First, define the types of "facts" that your rules can match against. This is done by including `ActiveRecordRules::Fact` into your models:

```ruby
class Post < ApplicationRecord; include ActiveRecordRules::Fact; end
class User < ApplicationRecord; include ActiveRecordRules::Fact; end
class PostTag < ApplicationRecord; include ActiveRecordRules::Fact; end
class TagSubscription < ApplicationRecord; include ActiveRecordRules::Fact; end
```

Then, you can define rules matching those tags, and what should happen when those rules fire:

```ruby
ActiveRecordRules.define_rule(<<~RULE)
  rule Email users when new post is created
    Post(id = post_id, title, created_at)
    User(id = user_id, name, email)
    PostTag(post_id, tag_id)
    TagSubscription(user_id, tag_id)
  on match
    # This is just Ruby code
    if created_at > 5.minutes.ago                 # if the post is new
      PostNotifier.send_email(name, email, title) # notify the users
    end
RULE
```

Rule executions are remembered by object id and variable bindings, so they will only fire once.

It's also possible to perform some action when a rule ceases to match. This can be done by adding an `on unmatch` section:

```ruby
ActiveRecordRules.define_rule(<<~RULE)
  rule Update number of posts for user
    Post(author_id, status = "published")
    User(id = author_id)
  on match
    User.find(author_id).increment!(:post_count)
  on unmatch
    User.find(author_id).decrement!(:post_count)
RULE
```

This rule will match when a post is put in the `published` state, and unmatch when it is removed from the `published` state.

## Development

This project uses Guix as its main dependency management system. A development environment can be created by running:

```sh
guix shell --development --file=guix.scm
```

## Contributing

Bug reports and changes are welcome on SourceHut at <https://sr.ht/~czan/active_record_rules/>.
