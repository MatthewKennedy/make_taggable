desc "Migrate db"

task :set_db do
  exec "cd spec/dummy && rake db:create && rake db:migrate"
end
