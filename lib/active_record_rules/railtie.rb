# frozen_string_literal: true

require "active_record_rules"

module ActiveRecordRules
  class Railtie < Rails::Railtie
    rake_tasks do
      task :load_rules do
        ActiveRecordRules.load_rules(
          Dir[Rails.root.join("app", "**", "*.rules")]
        )
      end

      Rake::Task["db:migrate"].enhance do
        Rake::Task[:load_rules].invoke
      end
    end
  end
end
