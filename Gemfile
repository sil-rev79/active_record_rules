# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in active_record_rules.gemspec
gemspec

gem "puma"

gem "sqlite3"

gem "sprockets-rails"

# Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
gem "rubocop-rails-omakase", require: false

# Start debugger with binding.b [https://github.com/ruby/debug]
# gem "debug", ">= 1.0.0"

group "test" do
  gem "rake", "~> 13.0"

  gem "rubocop", "~> 1.48"

  gem "rubocop-rspec", "~> 2.19"

  gem "rspec", "~> 3"

  gem "rails", "~> 7"

  gem "pg"

  gem "properb", git: "https://git.sr.ht/~czan/properb"

  gem "simplecov"
end
