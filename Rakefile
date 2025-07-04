require "bundler/setup"

APP_RAKEFILE = File.expand_path("test_application/Rakefile", __dir__)
load "rails/tasks/engine.rake"

load "rails/tasks/statistics.rake"

require "bundler/gem_tasks"

require "rspec/core/rake_task"
RSpec::Core::RakeTask.new(:spec)
# RuboCop::RakeTask.new
task default: %i[spec rubocop]
