# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module ActiveRecordRules
  class InstallGenerator < ActiveRecord::Generators::Base # :nodoc:
    argument :name, type: :string, default: "???"

    desc "Generates a migration for ActiveRecordRules models."

    class_option :id_type, type: :string, default: "integer", desc: "The column type to use to track fact ids"
    class_option :json_type, type: :string, default: "json", desc: <<~DESC
      The column type to use for JSON payloads. This should be "jsonb" for Postgres and "json" for SQLite.
    DESC

    source_root __dir__

    def apply_migration_template
      @id_type = options[:id_type]
      @json_type = options[:json_type]
      migration_template "migration.rb.erb", "db/migrate/create_active_record_rules_tables.rb"
    end

    def migration_version
      format("[%d.%d]", ActiveRecord::VERSION::MAJOR, ActiveRecord::VERSION::MINOR) # rubocop:disable Style/FormatStringToken
    end
  end
end
