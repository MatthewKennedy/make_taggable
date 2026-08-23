# frozen_string_literal: true

require "make_taggable/version"
require "active_record"
require "active_record/version"
require "active_support/core_ext/module"

begin
  require "rails/engine"
  require "make_taggable/engine"
rescue LoadError
end

require "digest/sha1"

##
# Tagging for Active Record models, across any number of named contexts.
#
# Make a model taggable with {MakeTaggable::Taggable#make_taggable}, and configure the library
# through {MakeTaggable.setup}. Every setting on {MakeTaggable::Configuration} can also be read and
# written directly here.
#
# @example
#   class Book < ActiveRecord::Base
#     make_taggable :genres
#   end
#
#   Book.create!(genre_list: "sci-fi, classic")
#   Book.tagged_with("sci-fi")
#
module MakeTaggable
  extend ActiveSupport::Autoload

  autoload :Tag
  autoload :TagList
  autoload :GenericParser
  autoload :DefaultParser
  autoload :Taggable
  autoload :Tagger
  autoload :Tagging
  autoload :TagsHelper
  autoload :VERSION

  autoload_under "taggable" do
    autoload :Cache
    autoload :Collection
    autoload :Core
    autoload :Ownership
    autoload :Related
  end

  autoload :Utils

  ##
  # Raised when a tag name is taken by a competing write and cannot be resolved by retrying.
  #
  class DuplicateTagError < StandardError
  end

  ##
  # Yields the configuration so settings can be assigned in one block.
  #
  # Called without a block it only ensures the configuration exists, which is how the library
  # initialises itself on load.
  #
  # @yieldparam configuration [MakeTaggable::Configuration] the current configuration
  # @return [MakeTaggable::Configuration, NilClass] the configuration when no block is given
  #
  # @example
  #   MakeTaggable.setup do |config|
  #     config.force_lowercase = true
  #     config.remove_unused_tags = true
  #   end
  #
  def self.setup
    @configuration ||= Configuration.new
    yield @configuration if block_given?
  end

  ##
  # Forwards unknown calls to the configuration, so every setting can be read and written directly
  # on `MakeTaggable` as well as inside a {setup} block.
  #
  # @param method_name [Symbol] the configuration reader or writer
  # @param args [Array<Object>] arguments forwarded to the configuration
  # @return [Object] whatever the configuration returns
  # @raise [NoMethodError] when the configuration has no such setting
  #
  # @example
  #   MakeTaggable.force_lowercase = true
  #   MakeTaggable.force_lowercase # => true
  #
  def self.method_missing(method_name, *args, &block)
    if @configuration.respond_to?(method_name)
      @configuration.send(method_name, *args, &block)
    else
      super
    end
  end

  ##
  # Reports the configuration's settings as available on `MakeTaggable` itself.
  #
  # @param method_name [Symbol] the method being tested
  # @param include_private [TrueClass, FalseClass] whether private methods count
  # @return [TrueClass, FalseClass]
  #
  def self.respond_to_missing?(method_name, include_private = false)
    @configuration.respond_to?(method_name, include_private) || super
  end

  ##
  # The string used to join tags back together for display, derived from the configured delimiter.
  #
  # A trailing space is added when the delimiter does not already end in one, so a comma delimiter
  # renders as `"one, two"` rather than `"one,two"`. When several delimiters are configured the
  # first is used.
  #
  # @return [String] the delimiter, guaranteed to end in a space
  #
  # @example
  #   MakeTaggable.glue # => ", "
  #
  def self.glue
    setting = @configuration.delimiter
    delimiter = setting.is_a?(Array) ? setting[0] : setting
    delimiter.end_with?(" ") ? delimiter : "#{delimiter} "
  end

  ##
  # The class tags are read, written and returned as.
  #
  # Resolved on each call rather than memoised, so a reloaded class in development is picked up.
  #
  # @return [Class]
  #
  def self.tag_model
    tag_class.constantize
  end

  ##
  # The library's settings.
  #
  # Reach these through {MakeTaggable.setup} or directly on `MakeTaggable`, which forwards to the
  # single instance held here.
  #
  # @!attribute [rw] force_lowercase
  #   Whether tag names are downcased before they are saved.
  #   @return [TrueClass, FalseClass] defaults to `false`
  # @!attribute [rw] force_parameterize
  #   Whether tag names are parameterized before they are saved.
  #   @return [TrueClass, FalseClass] defaults to `false`
  # @!attribute [rw] remove_unused_tags
  #   Whether a tag row is destroyed once its last tagging goes away. Works with or without
  #   `tags_counter`; without it the check costs one extra query per destroyed tagging.
  #   @return [TrueClass, FalseClass] defaults to `false`
  # @!attribute [rw] default_parser
  #   The class used to turn tag input into a {MakeTaggable::TagList}.
  #   @return [Class] defaults to {MakeTaggable::DefaultParser}
  # @!attribute [rw] tags_counter
  #   Whether taggings maintain a counter cache on their tag.
  #   @return [TrueClass, FalseClass] defaults to `true`
  # @!attribute [rw] tags_table
  #   The table backing {MakeTaggable::Tag}.
  #   @return [Symbol, String] defaults to `:tags`
  # @!attribute [rw] taggings_table
  #   The table backing {MakeTaggable::Tagging}.
  #   @return [Symbol, String] defaults to `:taggings`
  # @!attribute [r] delimiter
  #   The delimiter, or delimiters, separating tags in a string. Metacharacters are escaped, so
  #   each one is matched literally.
  #   @return [String, Array<String>] defaults to `","`
  # @!attribute [r] strict_case_match
  #   Whether tag lookups are case sensitive.
  #   @return [TrueClass, FalseClass] defaults to `false`
  #
  class Configuration
    attr_accessor :force_lowercase, :force_parameterize,
      :remove_unused_tags, :default_parser,
      :tags_counter, :tags_table,
      :taggings_table
    attr_reader :delimiter, :strict_case_match, :tag_class

    ##
    # Builds the configuration with the library's defaults.
    #
    # @return [MakeTaggable::Configuration]
    #
    def initialize
      @delimiter = ","
      @force_lowercase = false
      @force_parameterize = false
      @strict_case_match = false
      @remove_unused_tags = false
      @tags_counter = true
      @default_parser = DefaultParser
      @force_binary_collation = false
      @tags_table = :tags
      @taggings_table = :taggings
      @tag_class = "MakeTaggable::Tag"
    end

    ##
    # Sets the class tags are read, written and returned as.
    #
    # Must be a String. A model constant cannot be referenced while initializers run -- Zeitwerk
    # has not defined it yet, and eager loading in production would try to resolve it before the
    # class exists.
    #
    # @param class_name [String] the name of a class inheriting from {MakeTaggable::Tag}
    # @return [String]
    # @raise [ArgumentError] when given anything but a String
    #
    def tag_class=(class_name)
      unless class_name.is_a?(String)
        raise ArgumentError,
          "tag_class must be a String, got #{class_name.inspect}. " \
          "Naming the class rather than the constant is what lets it be set in an initializer, " \
          "before Zeitwerk has defined it."
      end

      @tag_class = class_name
    end

    ##
    # Sets whether tag lookups are case sensitive.
    #
    # Ignored while {#force_binary_collation=} is on, which already implies case sensitivity.
    #
    # @param force_cs [TrueClass, FalseClass] whether to match case exactly
    # @return [TrueClass, FalseClass]
    #
    def strict_case_match=(force_cs)
      @strict_case_match = force_cs unless @force_binary_collation
    end

    ##
    # Sets the delimiter separating tags in a string.
    #
    # @deprecated Configure a {#default_parser} instead. This will be removed in a future release.
    #
    # @param string [String, Array<String>] one delimiter, or several
    # @return [String, Array<String>]
    #
    # @example Several delimiters, matched literally
    #   MakeTaggable.delimiter = [",", "|"]
    #
    def delimiter=(string)
      # Active Record does not always have a logger -- a plain Active Record
      # process, or an initializer running before the logger is assigned, will
      # both leave it nil.
      ActiveRecord::Base.logger&.warn(
        "MakeTaggable.delimiter is deprecated and will be removed in a future " \
        "release. Configure a MakeTaggable.default_parser instead."
      )
      @delimiter = string
    end

    ##
    # Switches the MySQL tag name column between a binary and a case-insensitive collation.
    #
    # A binary collation makes tag names compare exactly, including accented and other multi-byte
    # characters, and forces {#strict_case_match} on. Does nothing on other adapters.
    #
    # @param force_bin [TrueClass, FalseClass] whether to apply the binary collation
    # @return [TrueClass, FalseClass]
    #
    def force_binary_collation=(force_bin)
      if Utils.using_mysql?
        if force_bin
          Configuration.apply_binary_collation(true)
          @force_binary_collation = true
          @strict_case_match = true
        else
          Configuration.apply_binary_collation(false)
          @force_binary_collation = false
        end
      end
    end

    ##
    # Alters the MySQL tag name column to the requested collation.
    #
    # Failures are reported rather than raised: the column does not exist yet the first time the
    # migrations run, and that is not an error.
    #
    # @param bincoll [TrueClass, FalseClass] `true` for `utf8mb4_bin`, `false` for
    #   `utf8mb4_general_ci`
    # @return [NilClass]
    #
    ##
    # Applies the collation `tags.name` should carry on MySQL, if it does not carry it already.
    #
    # This is a schema change, and the documented way to reach it is an initializer -- which runs
    # once per process, so once per web worker, background worker, console and rake task. Issuing
    # `ALTER TABLE` from each of those takes a metadata lock on the tags table every time. So the
    # current collation is read first and the statement skipped when it already matches, which
    # turns the common case into one cheap catalogue read.
    #
    # @param bincoll [TrueClass, FalseClass] whether to apply the binary collation
    # @return [void]
    #
    def self.apply_binary_collation(bincoll)
      return unless Utils.using_mysql?

      collation = bincoll ? "utf8mb4_bin" : "utf8mb4_general_ci"

      # Nothing to apply to yet -- this runs during the first migration, before
      # the table exists.
      return unless Utils.connection.table_exists?(Tag.table_name)
      return if current_tag_name_collation == collation

      ActiveRecord::Migration.execute(
        "ALTER TABLE #{Tag.table_name} MODIFY name varchar(255) CHARACTER SET utf8mb4 COLLATE #{collation};"
      )
    end

    ##
    # The collation `tags.name` currently carries, or `nil` where it cannot be read.
    #
    # @return [String, NilClass]
    #
    def self.current_tag_name_collation
      Utils.connection.columns(Tag.table_name).find { |column| column.name == "name" }&.collation
    end
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
