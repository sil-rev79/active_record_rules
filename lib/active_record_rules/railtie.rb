# frozen_string_literal: true

require "active_record_rules"

module ActiveRecordRules
  class Railtie < Rails::Railtie
    rake_tasks do
      namespace :rules do
        desc "Load rules from configured search paths (automatially run after db:migrate and db:{schema,structure}:load"
        task load: :environment do
          if ActiveRecordRules.automatic_load_paths
            ActiveRecordRules.load_rules(
              *ActiveRecordRules.automatic_load_paths.map { Dir[_1] }
            )
          end
        end
      end

      Rake::Task["db:migrate"].enhance do
        Rake::Task["rules:load"].invoke
      end

      Rake::Task["db:schema:load"].enhance do
        Rake::Task["rules:load"].invoke
      end

      Rake::Task["db:structure:load"].enhance do
        Rake::Task["rules:load"].invoke
      end
    end
  end
end
