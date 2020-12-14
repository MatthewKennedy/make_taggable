desc "Migrate db"

task :set_db do
  cp "spec/dummy/config/pg_database.yml.ci", "spec/dummy/config/database.yml"
  exec "cd spec/dummy && rake db:migrate"
end
