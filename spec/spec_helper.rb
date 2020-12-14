# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require_relative "../spec/dummy/config/environment"

require "rspec/rails"
require "rails"

Dir["./spec/support/**/*.rb"].sort.each { |f| require f }
