require "active_record"
require "logger"
require "make_taggable"

require_relative "support/database"
require_relative "support/models"
require_relative "support/helpers"
require_relative "support/array"

# Model classes the suite declares tags on. Examples that call make_taggable or
# make_ordered_taggable on one of these change it for every example that
# follows, so the declarations are snapshotted and restored around each one.
TAGGABLE_MODELS = ObjectSpace.each_object(Class).select { |klass|
  klass < ActiveRecord::Base && klass.respond_to?(:taggable?) && klass.taggable?
}.freeze

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed

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

  # Restore anything global an example changed, so the order examples run in
  # cannot affect their outcome: the tagging declarations on the shared models,
  # and the library configuration.
  #
  # The configuration is restored through its instance variables rather than its
  # writers, so that delimiter= does not log a deprecation on every example.
  config.around do |example|
    declarations = TAGGABLE_MODELS.map { |klass| [klass, klass.tag_types.dup, klass.preserve_tag_order] }
    configuration = MakeTaggable.instance_variable_get(:@configuration)
    settings = configuration.instance_variables.to_h { |ivar| [ivar, configuration.instance_variable_get(ivar)] }

    example.run
  ensure
    declarations.each do |klass, tag_types, preserve_tag_order|
      klass.tag_types = tag_types unless klass.tag_types == tag_types
      klass.preserve_tag_order = preserve_tag_order unless klass.preserve_tag_order == preserve_tag_order
    end
    settings.each { |ivar, value| configuration.instance_variable_set(ivar, value) }
  end
end
