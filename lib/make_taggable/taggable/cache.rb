module MakeTaggable::Taggable
  module Cache
    def self.included(base)
      # When included, conditionally adds tag caching methods when the model
      #   has any "cached_#{tag_type}_list" column
      base.extend MakeTaggable::Taggable::Columns
    end

    module ClassMethods
      def initialize_tags_cache
        tag_types.map(&:to_s).each do |tag_type|
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def self.caching_#{tag_type.singularize}_list?
              caching_tag_list_on?("#{tag_type}")
            end
          RUBY
        end
      end

      def make_taggable(*args)
        super(*args)
        initialize_tags_cache
      end

      def caching_tag_list_on?(context)
        column_names.include?("cached_#{context.to_s.singularize}_list")
      end
    end

    module InstanceMethods
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
