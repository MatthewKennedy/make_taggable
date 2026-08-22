require "active_record"
require "logger"
require "make_taggable"

require_relative "support/database"
require_relative "support/models"
require_relative "support/helpers"
require_relative "support/array"

RSpec.configure do |config|
  config.disable_monkey_patching!

  # Defined order, deliberately. A number of examples mutate shared model
  # classes (TaggableModel.make_taggable :array, preserve_tag_order flips) and
  # rely on siblings having run first. Randomising exposes that, but untangling
  # it is separate work -- see docs/CONTRIBUTING notes.
  config.order = :defined

  config.expect_with(:rspec) { |expectations| expectations.syntax = :expect }
  config.mock_with(:rspec) { |mocks| mocks.verify_partial_doubles = true }

  # Every example runs inside a transaction that is rolled back afterwards, so
  # examples never see each other's rows.
  config.around do |example|
    ActiveRecord::Base.transaction do
      example.run
      raise ActiveRecord::Rollback
    end
  end
end
