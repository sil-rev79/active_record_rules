# frozen_string_literal: true

require "active_record_rules"

module ActiveRecordRules
  class Railtie < Rails::Railtie
    rake_tasks do
      task :load_rules do
        if ActiveRecordRules.load_rules_after_migrations
          ActiveRecordRules.load_rules(
            Dir[Rails.root.join("app", "**", "*.rules")]
          )
        end
      end

      Rake::Task["db:migrate"].enhance do
        Rake::Task[:load_rules].invoke
      end

      Rake::Task["db:schema:load"].enhance do
        Rake::Task[:load_rules].invoke
      end
    end
  end
end
