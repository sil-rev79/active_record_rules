# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"
require "rails/generators/migration"

module ActiveRecordRules
  class InstallGenerator < ActiveRecord::Generators::Base # :nodoc:
    desc "Generates a migration for ActiveRecordRules models."

    class_option :id_type, type: :string, default: "integer", desc: <<~DESC
      The column type to use to track record ids. This can be any
      type, but common values are integer (Rails' default) or uuid.
    DESC

    source_root __dir__

    def apply_dialect_template
      template "set_dialect.rb.erb", "config/initializers/active_record_rules.rb"
    end

    def apply_migration_templates
      migration_template "create_tables.rb.erb", "db/migrate/create_active_record_rules_tables.rb"
    end

    def dialect = name

    def json_type
      case name
      in "postgres"
        "jsonb"
      in "sqlite"
        "json"
      else
        raise "Unsupported dialect: #{name}. Only postgres and sqlite are supported."
      end
    end

    def primary_key_type
      config = Rails.configuration.generators
      config.options[config.orm][:primary_key_type] || :primary_key
    rescue StandardError
      :integer
    end

    def migration_version
      format("[%d.%d]", ActiveRecord::VERSION::MAJOR, ActiveRecord::VERSION::MINOR) # rubocop:disable Style/FormatStringToken
    end
  end
end
