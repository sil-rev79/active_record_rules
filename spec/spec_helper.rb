# frozen_string_literal: true

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
    ActiveRecord::Base.establish_connection(
      adapter: "sqlite3",
      database: ":memory:"
    )

    Dir.mktmpdir do |dir|
      Rails::Generators.invoke(
        "active_record_rules:install",
        ["--id_type=integer", "--quiet"],
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
