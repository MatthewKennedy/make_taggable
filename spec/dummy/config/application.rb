require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)
require "make_taggable"

module Dummy
  class Application < Rails::Application
    config.generators.system_tests = nil
  end
end
