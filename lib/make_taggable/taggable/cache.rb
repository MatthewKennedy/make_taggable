# frozen_string_literal: true

module MakeTaggable::Taggable
  ##
  # Keeps a rendered copy of a tag list in a column on the taggable itself, so a list can be shown
  # without loading its tags.
  #
  # Caching switches itself on for any context the model has a matching `cached_<context>_list`
  # column for. Nothing else is required.
  #
  # @example Caching the default context
  #   add_column :books, :cached_tag_list, :string
  #
  module Cache
    ##
    # @param base [Class] the model being made taggable
    # @return [void]
    #
    # @api private
    #
    def self.included(base)
      # When included, conditionally adds tag caching methods when the model
      #   has any "cached_#{tag_type}_list" column
      base.extend Columns
    end

    ##
    # Intercepts the model's column lookup so caching can be wired up the first time the schema is
    # known, without opening a database connection when the class is loaded.
    #
    module Columns
      ##
      # The model's columns, injecting the caching methods the first time they are asked for.
      #
      # @return [Array<ActiveRecord::ConnectionAdapters::Column>]
      #
      def columns
        @make_taggable_cache_columns ||= begin
          db_columns = super
          _add_tags_caching_methods if _has_tags_cache_columns?(db_columns)
          db_columns
        end
      end

      ##
      # Forgets the cached column lookup along with Active Record's own.
      #
      # @return [void]
      #
      def reset_column_information
        super
        @make_taggable_cache_columns = nil
      end

      private

      # @private
      def _has_tags_cache_columns?(db_columns)
        db_column_names = db_columns.map(&:name)
        tag_types.any? do |context|
          db_column_names.include?("cached_#{context.to_s.singularize}_list")
        end
      end

      # @private
      def _add_tags_caching_methods
        send :include, MakeTaggable::Taggable::Cache::InstanceMethods
        extend MakeTaggable::Taggable::Cache::ClassMethods

        before_save :save_cached_tag_list

        initialize_tags_cache
      end
    end

    ##
    # Added to a model once it has at least one caching column.
    #
    module ClassMethods
      ##
      # Defines a `caching_<context>_list?` predicate for each context.
      #
      # @return [void]
      #
      def initialize_tags_cache
        tag_types.map(&:to_s).each do |tag_type|
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def self.caching_#{tag_type.singularize}_list?
              caching_tag_list_on?("#{tag_type}")
            end
          RUBY
        end
      end

      ##
      # Adds contexts and refreshes the caching predicates.
      #
      # @param args [Array<Symbol, String>] the contexts to add
      # @return [void]
      #
      def make_taggable(*args)
        super
        initialize_tags_cache
      end

      ##
      # Whether a context's tag list is cached on the model.
      #
      # @param context [Symbol, String] the tagging context
      # @return [TrueClass, FalseClass]
      #
      def caching_tag_list_on?(context)
        column_names.include?("cached_#{context.to_s.singularize}_list")
      end
    end

    ##
    # Added to a model once it has at least one caching column.
    #
    module InstanceMethods
      ##
      # Writes each cached tag list into its column. Runs before save.
      #
      # @return [TrueClass]
      #
      def save_cached_tag_list
        tag_types.map(&:to_s).each do |tag_type|
          if self.class.send("caching_#{tag_type.singularize}_list?")
            if tag_list_cache_set_on(tag_type)
              list = tag_list_cache_on(tag_type).to_a.flatten.compact.join("#{MakeTaggable.delimiter} ")
              self["cached_#{tag_type.singularize}_list"] = list
            end
          end
        end

        true
      end
    end
  end
end
