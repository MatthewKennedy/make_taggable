require "fileutils"

desc "Set up the test app for"
task :test_app do
  ENV['RAILS_ENV'] = 'test'
  exec "cd spec/dummy && rake make_taggable_engine:install:migrations && rake db:create RAILS_ENV=test && rake db:migrate RAILS_ENV=test"
end
