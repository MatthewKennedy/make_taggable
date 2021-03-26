module MakeTaggable
  module Taggable
    module Columns
      # ActiveRecord::Base.columns makes a database connection and caches the
      #   calculated columns hash for the record as @columns.  Since we don't
      #   want to add caching methods until we confirm the presence of a
      #   caching column, and we don't want to force opening a database
      #   connection when the class is loaded, here we intercept and cache
      #   the call to :columns as @make_taggable_cache_columns
      #   to mimic the underlying behavior.  While processing this first
      #   call to columns, we do the caching column check and dynamically add
      #   the class and instance methods
      def columns
        @make_taggable_cache_columns ||= begin
          db_columns = super
          _add_tags_caching_methods if _has_tags_cache_columns?(db_columns)
          db_columns
        end
      end

      def reset_column_information
        super
        @make_taggable_cache_columns = nil
      end

      private

      def _has_tags_cache_columns?(db_columns)
        db_column_names = db_columns.map(&:name)
        tag_types.any? do |context|
          db_column_names.include?("cached_#{context.to_s.singularize}_list")
        end
      end

      def _add_tags_caching_methods
        send :include, MakeTaggable::Taggable::Cache::InstanceMethods
        extend MakeTaggable::Taggable::Cache::ClassMethods

        before_save :save_cached_tag_list

        initialize_tags_cache
      end
    end
  end
end
