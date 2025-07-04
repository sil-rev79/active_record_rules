require "rails"

module ActiveRecordRules
  class Engine < ::Rails::Engine
    isolate_namespace ActiveRecordRules

    initializer "active_record_rules.assets.precompile" do |app|
      app.config.assets.precompile += %w[ active_record_rules/application.css active_record_rules/pico.min.css ]
    end
  end
end
