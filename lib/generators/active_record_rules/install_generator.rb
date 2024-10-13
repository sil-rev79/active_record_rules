# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"
require "rails/generators/migration"

module ActiveRecordRules
  class InstallGenerator < ActiveRecord::Generators::Base # :nodoc:
    desc "Generates a migration for ActiveRecordRules models."
    argument :name, type: :string, default: "" # We don't use/need the name

    source_root __dir__

    def apply_dialect_template
      template "rails_config.rb.erb", "config/initializers/active_record_rules.rb"
    end

    def apply_migration_templates
      migration_template "create_tables.rb.erb", "db/migrate/create_active_record_rules_tables.rb"
    end

    def postgres? = ActiveRecordRules.dialect == :postgres

    def json_type
      case ActiveRecordRules.dialect
      in :postgres
        "jsonb"
      in :sqlite
        "json"
      end
    end

    def id_type
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
