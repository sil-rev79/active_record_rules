# frozen_string_literal: true

require "active_record"
require "active_record_rules"
require "generators/active_record_rules/install_generator"
require "tmpdir"

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

    example.run
  end

  config.include RSpecExtensions
end
