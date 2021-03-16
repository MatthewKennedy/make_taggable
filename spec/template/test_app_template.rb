def source_paths
  [__dir__]
end

def add_make_taggable_to_application_rb
  append_to_file("config/application.rb", "\nrequire 'make_taggable'\n", after: "Bundler.require(*Rails.groups)")
end

gem_group :development, :test do
  gem "make_taggable", path: "../../../make_taggable"
end

def copy_templates
  directory "app", force: true
  directory "db/migrate", force: true
  directory "config/boot.rb", force: true
end

def migrate_test_db
  run "bundle exec rake db:migrate RAILS_ENV=test"
end

def remove_gem_files
  run "rm gemfile"
  run "rm Gemfile.lock"
end
after_bundle do
  add_make_taggable_to_application_rb
  copy_templates
  migrate_test_db
 # remove_gem_files
end
