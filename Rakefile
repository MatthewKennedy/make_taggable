require "bundler/gem_tasks"
require "rails/dummy/tasks"

import "./lib/tasks/tags_collate_utf8.rake"

APP_RAKEFILE = File.expand_path("spec/dummy/Rakefile", __dir__)

require "rspec/core/rake_task"
RSpec::Core::RakeTask.new(:spec)

task default: :spec

load "lib/tasks/setup_test_db.rake"
