# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = "active_record_rules"
  spec.version = File.open("guix.scm") { _1.read.match(/\(version "(.*)"\) *; for gemspec/)[1] }
  spec.authors = ["Carlo Zancanaro"]
  spec.email = ["carlo@zancanaro.id.au"]
  spec.license = "GPL-3.0-only"

  spec.summary = "Database-driven production rules in Ruby"
  spec.description = <<~TEXT
    A production rule library that uses database records as its
    working memory.
  TEXT

  spec.homepage = "https://sr.ht/~czan/active_record_rules/"
  spec.required_ruby_version = ">= 3.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://sr.ht/~czan/active_record_rules/"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(__dir__) do
    [
      "README.md",
      "COPYING",
      *Dir["app/**/*"],
      *Dir["config/**/*"],
      *Dir["lib/**/*"],
    ]
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord", ">= 7"
  spec.add_dependency "parslet", ">= 2"
  spec.add_dependency "rails", ">= 7"
end
