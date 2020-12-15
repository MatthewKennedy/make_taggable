$:.push File.expand_path("../lib", __FILE__)

require "make_taggable/version"

Gem::Specification.new do |spec|
  spec.name = "make_taggable"
  spec.version = MakeTaggable::VERSION
  spec.authors = ["Matthew Kennedy", "Michael Bleigh", "Joost Baaij"]
  spec.email = %w[m.kennedy@me.com]
  spec.description = "MakeTaggable is a fork of Acts-As-Taggable-On with code updates & fresh migrations"
  spec.summary = "Advanced Tagging For Rails"
  spec.homepage = "https://github.com/MatthewKennedy/make_taggable"
  spec.license = "MIT"

  if File.exist?("UPGRADING.md")
    spec.post_install_message = File.read("UPGRADING.md")
  end

  spec.files = `git ls-files`.split($/)
  spec.test_files = spec.files.grep(%r{^spec/})
  spec.require_paths = ["lib"]

  spec.add_dependency "rails", ">= 5.2.0", "< 6.2"

  spec.add_development_dependency "appraisal", ">= 2.0.0", "< 3.0.0"
  spec.add_development_dependency "mysql2", ">= 0.5.0", "< 0.6.0"
  spec.add_development_dependency "pg", ">= 1.2.0", "< 2.0.0"
  spec.add_development_dependency "rspec", ">= 3.10.0", "< 4.0.0"
  spec.add_development_dependency "rspec-rails", ">= 4.0.0", "< 5.0.0"
  spec.add_development_dependency "standard", ">= 0.10.0", "< 1.0.0"
  spec.add_development_dependency "sqlite3", ">= 1.4.0", "< 2.0.0"
end
