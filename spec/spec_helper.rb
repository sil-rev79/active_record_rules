# frozen_string_literal: true

# Run tests with coverage report information
if ENV["TRACK_COVERAGE"]
  require "simplecov"

  # Due to the way I do development, using Guix, the coverage report
  # can't write over the top of the previous one without some
  # help. The easiest way: remove the old coverage report when running
  # tests again.
  Pathname.new(__FILE__).join("..", "..", "coverage").tap do |dir|
    # clear old coverage results
    FileUtils.rm_rf(dir) if dir.exist?
  end
  SimpleCov.start do
    enable_coverage :branch
    primary_coverage :branch
  end
end

require "active_record"
require "active_record_rules"
require "generators/active_record_rules/install_generator"
require "tmpdir"
require "properb"

module RSpecExtensions
  def define_tables(&block)
    block.call(ActiveRecord::Base.connection)
  end

  def capturing_logs(level = :debug, &block)
    output = StringIO.new
    old = ActiveRecordRules.logger
    ActiveRecordRules.logger = Logger.new(output, level: level)
    block.call(output)
  ensure
    ActiveRecordRules.logger = old
  end
end

module TestHelper
  # This is just a global place to put information about rule
  # matches, to simplify tests.
  cattr_accessor :matches
end

class TestRecord < ActiveRecord::Base
  self.abstract_class = true

  after_commit ->(object) { ActiveRecordRules.trigger([object]) }
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.around do |example|
    connection_string = ENV.fetch("ARR_DATABASE", "sqlite3::memory:")

    ActiveRecordRules.dialect = if connection_string.start_with?("postgres")
                                  :postgres
                                elsif connection_string.start_with?("sqlite")
                                  :sqlite
                                else
                                  raise "We only support Postgres and SQLite for now. Sorry!"
                                end

    if ActiveRecordRules.dialect == :postgres
      # Connect to the "postgres" database and drop+create the
      # database we want to use
      db_name = connection_string.match(%r{/([^/]*)(\?|$)})[1]
      ActiveRecord::Base.establish_connection(connection_string.gsub("/#{db_name}", "/postgres"))
      ActiveRecord::Base.connection.drop_database(db_name)
      ActiveRecord::Base.connection.create_database(db_name)
    end

    ActiveRecord::Base.establish_connection(connection_string)

    Dir.mktmpdir do |dir|
      Rails::Generators.invoke(
        "active_record_rules:install",
        [ActiveRecordRules.dialect.to_s, "--quiet"],
        destination_root: dir
      )

      ActiveRecord::Migration.suppress_messages do
        ActiveRecord::MigrationContext.new(
          "#{dir}/db/migrate",
          ActiveRecord::Base.connection.schema_migration
        ).migrate
      end
    end

    # Set up a logger that goes nowhere. This ensures that we always
    # run the logging-related code so we make sure it doesn't crash.
    ActiveRecordRules.logger = Logger.new(StringIO.new)

    example.run
  end

  config.include RSpecExtensions

  Properb.rspec_install(config)
end
