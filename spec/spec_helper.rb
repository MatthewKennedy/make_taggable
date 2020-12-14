# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require_relative "../spec/dummy/config/environment"

require "rspec/rails"
require "rails"

Dir["./spec/support/**/*.rb"].sort.each { |f| require f }

RSpec.configure do |config|
  config.fixture_path = "spec/fixtures"
  config.global_fixtures = :all
  config.use_transactional_fixtures = true
  config.infer_base_class_for_anonymous_controllers = true
end
