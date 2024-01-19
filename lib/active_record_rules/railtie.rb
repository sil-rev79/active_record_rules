# frozen_string_literal: true

require "active_record_rules"

module ActiveRecordRules
  class Railtie < Rails::Railtie
    rake_tasks do
      task :load_rules do
        if ActiveRecordRules.automatic_load_paths
          ActiveRecordRules.load_rules(
            *ActiveRecordRules.automatic_load_paths.map { Dir[_1] }
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
