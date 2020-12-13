desc "Sets up test enviroment"

task :test_pg do
  cp "spec/dummy/config/database.yml.ci", "spec/dummy/config/database.yml"
  exec "cd spec/dummy && rake db:create"
end
