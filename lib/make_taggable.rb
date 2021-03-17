require "active_record"
require "active_record/version"
require "active_support/core_ext/module"
require "digest/sha1"
require "make_taggable/version"
require "zeitwerk"

begin
  require "rails/engine"
  require "make_taggable/engine"
rescue LoadError
end

loader = Zeitwerk::Loader.for_gem
loader.setup

module MakeTaggable
  def self.setup
    @configuration ||= MakeTaggable::Configuration.new
    yield @configuration if block_given?
  end

  def self.method_missing(method_name, *args, &block)
    if @configuration.respond_to?(method_name)
      @configuration.send(method_name, *args, &block)
    else
      super
    end
  end

  def self.respond_to_missing?(method_name, include_private = false)
    @configuration.respond_to? method_name
  end

  def self.glue
    setting = @configuration.delimiter
    delimiter = setting.is_a?(Array) ? setting[0] : setting
    delimiter.end_with?(" ") ? delimiter : "#{delimiter} "
  end

  setup
end

ActiveSupport.on_load(:active_record) do
  extend MakeTaggable::Taggable
  include MakeTaggable::Tagger
end

ActiveSupport.on_load(:action_view) do
  include MakeTaggable::TagsHelper
end
