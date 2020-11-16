# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'acts_as_taggable_on/version'

Gem::Specification.new do |gem|
  gem.name          = 'uggle'
  gem.version       = ActsAsTaggableOn::VERSION
  gem.authors       = ['Matthew Kennedy', 'Michael Bleigh', 'Joost Baaij']
  gem.email         = %w(m.kennedy@me.com michael@intridea.com joost@spacebabies.nl)
  gem.description   = %q{Uggle is a clone of ActsAsTaggableOn v6.5 with updates. you can tag a single model on several contexts, such as skills, interests, and awards. It also provides other advanced functionality.}
  gem.summary       = 'Advanced tagging for Rails 6'
  gem.homepage      = 'https://github.com/MatthewKennedy/uggle'
  gem.license       = 'MIT'

  gem.files         = `git ls-files`.split($/)
  gem.test_files    = gem.files.grep(%r{^spec/})
  gem.require_paths = ['lib']
  gem.required_ruby_version     = '>= 2.5.0'

  if File.exist?('UPGRADING.md')
    gem.post_install_message = File.read('UPGRADING.md')
  end

  gem.add_runtime_dependency 'activerecord', '>= 5.0', '< 6.1'

  gem.add_development_dependency 'rspec-rails'
  gem.add_development_dependency 'rspec-its'
  gem.add_development_dependency 'rspec'
  gem.add_development_dependency 'barrier'
  gem.add_development_dependency 'database_cleaner'
  gem.add_development_dependency 'sqlite3'
end
