desc "Create a test app"
task :create_test_app do
  ENV["RAILS_ENV"] = "test"
  ENV["ENGINE"] = "make_taggable_engine"
  Rake::Task["dummy:app"].invoke
end
