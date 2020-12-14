desc "Migrate db"

task :set_db do

  exec "cd spec/dummy && rake make_taggable_engine:install:migrations && rake db:create && rake db:migrate"
end
