$:.push File.expand_path("../lib", __FILE__)

require "make_taggable/version"

Gem::Specification.new do |spec|
  spec.name = "make_taggable"
  spec.version = MakeTaggable::VERSION
  spec.authors = ["Matthew Kennedy", "Michael Bleigh", "Joost Baaij"]
  spec.email = %w[m.kennedy@me.com michael@intridea.com joost@spacebabies.nl]
  spec.description = "A fork of acts-as-taggable-on v6.5 with code updates and a new set of migrations."
  spec.summary = "Advanced Tagging For Rails"
  spec.homepage = "https://github.com/MatthewKennedy/make_taggable"
  spec.license = "MIT"

  if File.exist?("UPGRADING.md")
    spec.post_install_message = File.read("UPGRADING.md")
  end

  spec.files = `git ls-files`.split($/)
  spec.test_files = spec.files.grep(%r{^spec/})
  spec.require_paths = ["lib"]

  spec.add_dependency "rails", ">= 5.2"

  spec.add_development_dependency "appraisal"
  spec.add_development_dependency "mysql2", "0.5.3"
  spec.add_development_dependency "pg"
  spec.add_development_dependency "rspec", ">=3.0"
  spec.add_development_dependency "rspec-rails"
  spec.add_development_dependency "sqlite3"
  spec.add_development_dependency "standard"
end
