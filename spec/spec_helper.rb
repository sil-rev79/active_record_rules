# frozen_string_literal: true

require "active_record"
require "active_record_rules"

module RSpecExtensions
  def define_tables(&block)
    block.call(ActiveRecord::Base.connection)
  end
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
    schema = ActiveRecord::Base.connection

    schema.create_table :conditions do |t|
      t.string :match_class
      t.string :match_conditions
    end

    schema.create_table :rules do |t|
      t.string :name
      t.string :definition
    end

    schema.create_table :condition_rules do |t|
      t.references :condition
      t.references :rule
      t.string :key
    end

    schema.create_table :condition_memories do |t|
      t.references :condition
      t.integer :entry_id # TODO: make id type depend on how people set up their database?
      t.index [:condition_id, :entry_id], unique: true
    end

    schema.create_table :rule_memories do |t|
      t.references :rule
      t.string :cached # actually json
      t.string :arguments # actually json
      t.index [:rule_id, :cached], unique: true # Note that arguments is *not* included in the uniqueness constraints
    end
    example.run
  end

  config.include RSpecExtensions
end
