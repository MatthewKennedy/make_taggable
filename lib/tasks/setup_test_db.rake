require 'fileutils'

desc "Set up the test app for"
task :test_app do
  FileUtils.cp_r Dir.glob('spec/support/migrations/*.rb'), 'spec/dummy/db/migrate'
  exec "cd spec/dummy && rake make_taggable_engine:install:migrations && rake db:create && rake db:migrate"
end



