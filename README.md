# ActiveRecordRules

A [production system][] within ActiveRecord to execute code when matching rule conditions.

[production system]: https://en.wikipedia.org/wiki/Production_system_(computer_science)

## Installation

This Gem can't be installed into other projects yet. Check back later for installation instructions.

## Usage

First, define the types of "facts" that your rules can match against. This is done by including `Fact` into your models:

```ruby
class Post < ApplicationRecord; include Fact; end
class User < ApplicationRecord; include Fact; end
class PostTag < ApplicationRecord; include Fact; end
class TagSubscription < ApplicationRecord; include Fact; end
```

Then, you can define rules matching those tags, and what should happen when those rules fire:

```ruby
ActiveRecordRules::Rule.create_from_definition(<<~RULE)
  rule Email users when new post is created
    Post(id = post_id, title, created_at)
    User(id = user_id, name, email)
    PostTag(post_id, tag_id)
    TagSubscription(user_id, tag_id)
  on activation
    # This is just Ruby code
    if created_at > 5.minutes.ago                 # if the post is new
      PostNotifier.send_email(name, email, title) # notify the users
    end
RULE
```

Rule executions are remembered by object id and variable bindings, so they will only fire once.

It's also possible to perform some action when a rule ceases to match. This can be done by adding an `on deactivate` section:

```ruby
ActiveRecordRules::Rule.create_from_definition(<<~RULE)
  rule Update number of posts for user
    Post(author_id, status = "published")
    User(id = author_id)
  on activation
    User.find(author_id).increment!(:post_count)
  on deactivation
    User.find(author_id).decrement!(:post_count)
RULE
```

This rule will activate when a post is put in the `published` state, and deactivate when it is removed from the `published` state.

## Development

This project uses Guix as its main dependency management system. A development environment can be created by running:

```sh
guix shell --development --file=guix.scm
```

## Contributing

Bug reports and changes are welcome on SourceHut at <https://sr.ht/~czan/active_record_rules/>.
