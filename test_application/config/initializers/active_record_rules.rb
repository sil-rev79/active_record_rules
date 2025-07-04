Rails.autoloaders.each do |loader|
  loader.ignore(Rails.root.join('app/**/*.rules.rb'))
end

Rails.application.config.to_prepare do
  pp "loading rule"
  ActiveRecordRules.load_files(
    Dir[Rails.root.join('app/**/*.rules.rb')]
  )
end

Rails.application.reloader.after_class_unload do
  pp "unloading rules"
  ActiveRecordRules.all_rules.each { ActiveRecordRules.deregister_rule!(_1) }
end
