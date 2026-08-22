require_relative "lib/make_taggable/version"

Gem::Specification.new do |spec|
  spec.name = "make_taggable"
  spec.version = MakeTaggable::VERSION
  spec.authors = ["Matthew Kennedy", "Michael Bleigh", "Joost Baaij"]
  spec.email = %w[m.kennedy@me.com]

  spec.required_ruby_version = ">= 3.2"

  spec.summary = "Advanced Tagging For Rails"
  spec.description = "MakeTaggable lets Active Record models carry tags across any number of " \
    "named contexts, with ownership, ordering, custom parsers and tag-cloud calculations."

  spec.homepage = "https://github.com/MatthewKennedy/make_taggable"
  spec.license = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/master/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"
  spec.metadata["documentation_uri"] = "#{spec.homepage}/blob/master/docs"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      f.match(%r{\A(spec|gemfiles|\.github)/}) || f.match(%r{\A(\.|Appraisals|Rakefile|Gemfile)})
    end
  end

  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord", ">= 7.2"

  if File.exist?("UPGRADING.md")
    spec.post_install_message = File.read("UPGRADING.md")
  end
end
