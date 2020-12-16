require_relative "lib/make_taggable/version"

Gem::Specification.new do |spec|
  spec.name = "make_taggable"
  spec.version = MakeTaggable::VERSION
  spec.authors = ["Matthew Kennedy", "Michael Bleigh", "Joost Baaij"]
  spec.email = %w[m.kennedy@me.com]

  spec.required_ruby_version = ">= 2.5"

  spec.summary = "Advanced Tagging For Rails"
  spec.description = "MakeTaggable is a fork of Acts-As-Taggable-On with code updates & fresh migrations"

  spec.homepage = "https://github.com/MatthewKennedy/make_taggable"
  spec.license = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "https://github.com/MatthewKennedy/make_taggable/blob/master/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path("..", __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(spec)/}) }
  end

  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "rails", ">= 5.2.0", "<= 6.2.0"

  spec.add_development_dependency "appraisal", "~> 2.3.0"
  spec.add_development_dependency "mysql2", "~> 0.5.0"
  spec.add_development_dependency "pg", "~> 1.2.0"
  spec.add_development_dependency "rspec", "~> 3.10.0"
  spec.add_development_dependency "rspec-rails", "~> 4.0.0"
  spec.add_development_dependency "standard", "~> 0.10.0"
  spec.add_development_dependency "sqlite3", "~> 1.4.0"

  if File.exist?("UPGRADING.md")
    spec.post_install_message = File.read("UPGRADING.md")
  end
end
