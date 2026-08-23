# frozen_string_literal: true

require_relative "tagged_with_query"
require_relative "tag_list_type"

module MakeTaggable::Taggable
  ##
  # The heart of tagging: the associations, the generated `<context>_list` readers and writers, and
  # the `tagged_with` query.
  #
  module Core
    ##
    # @param base [Class] the model being made taggable
    # @return [void]
    #
    # @api private
    #
    def self.included(base)
      base.extend MakeTaggable::Taggable::Core::ClassMethods

      base.class_eval do
        attr_writer :custom_contexts
        after_save :save_tags
      end

      base.initialize_make_taggable_core
    end

    ##
    # Added to every taggable model.
    #
    module ClassMethods
      ##
      # Builds the associations and the `<context>_list` methods for each context.
      #
      # @return [void]
      #
      def initialize_make_taggable_core
        include taggable_mixin

        tag_types.map(&:to_s).each do |tags_type|
          tag_type = tags_type.to_s.singularize
          context_taggings = :"#{tag_type}_taggings"
          context_tags = tags_type.to_sym
          taggings_order = (preserve_tag_order? ? "#{MakeTaggable::Tagging.table_name}.id" : [])

          class_eval do
            # when preserving tag order, include order option so that for a 'tags' context
            # the associations tag_taggings & tags are always returned in created order
            has_many context_taggings, -> { includes(:tag).order(taggings_order).where(context: tags_type) },
              as: :taggable,
              class_name: "MakeTaggable::Tagging",
              dependent: :destroy,
              after_add: :dirtify_tag_list,
              after_remove: :dirtify_tag_list

            has_many context_tags, -> { order(taggings_order) },
              class_name: "MakeTaggable::Tag",
              through: context_taggings,
              source: :tag

            attribute :"#{tags_type.singularize}_list", MakeTaggable::Taggable::TagListType.new
          end

          taggable_mixin.class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def #{tag_type}_list
              tag_list_on('#{tags_type}')
            end

            def #{tag_type}_list=(new_tags)
              parsed_new_list = MakeTaggable.default_parser.new(new_tags).parse

              if self.class.preserve_tag_order? || (parsed_new_list.sort != #{tag_type}_list.sort)
                unless #{tag_type}_list_changed?
                  @attributes["#{tag_type}_list"] = ActiveModel::Attribute.from_user("#{tag_type}_list", #{tag_type}_list, MakeTaggable::Taggable::TagListType.new)
                end
                write_attribute("#{tag_type}_list", parsed_new_list)
              end

              set_tag_list_on('#{tags_type}', new_tags)
            end

            def all_#{tags_type}_list
              all_tags_list_on('#{tags_type}')
            end

            private
            def dirtify_tag_list(tagging)
              attribute_will_change! tagging.context.singularize+"_list"
            end
          RUBY
        end
      end

      ##
      # Adds contexts and rebuilds the generated methods.
      #
      # @param preserve_tag_order [TrueClass, FalseClass] whether to keep tags in the order added
      # @param tag_types [Array<Symbol, String>] the contexts to add
      # @return [void]
      #
      # @api private
      #
      def taggable_on(preserve_tag_order, *tag_types)
        super
        initialize_make_taggable_core
      end

      # all column names are necessary for PostgreSQL group clause
      def grouped_column_names_for(object)
        object.column_names.map { |column| "#{object.table_name}.#{column}" }.join(", ")
      end

      ##
      # Records tagged with the given tags.
      #
      # By default a record must carry every tag given. `:any` relaxes that to at least one, and
      # `:exclude` inverts it to none.
      #
      # @param tags [String, Array<String>] the tags to match
      # @param options [Hash] the query options
      # @option options [TrueClass, FalseClass] :any match records carrying any of the tags
      # @option options [TrueClass, FalseClass] :exclude match records carrying none of the tags
      # @option options [TrueClass, FalseClass] :match_all match records carrying only these tags
      # @option options [TrueClass, FalseClass] :wild match tags containing the given text
      # @option options [TrueClass, FalseClass] :order_by_matching_tag_count with `:any`, order by
      #   how many tags matched, most first
      # @option options [ActiveRecord::Base] :owned_by only tags applied by this tagger
      # @option options [Symbol, String] :on only tags applied in this context
      # @option options [Time, Date] :start_at only tags applied after this time
      # @option options [Time, Date] :end_at only tags applied before this time
      # @return [ActiveRecord::Relation] empty when no tags are given, except under `:exclude`,
      #   where excluding no tags leaves the whole scope standing
      #
      # @example Every tag
      #   User.tagged_with(["awesome", "cool"])
      #
      # @example Any tag, most matches first
      #   User.tagged_with(["awesome", "cool"], any: true, order_by_matching_tag_count: true)
      #
      # @example Scoped to a context and an owner
      #   Photo.tagged_with("paris", on: :locations, owned_by: @user)
      #
      def tagged_with(tags, options = {})
        tag_list = MakeTaggable.default_parser.new(tags).parse
        options = options.dup

        # Asking for no tags matches nothing, but *excluding* no tags rules
        # nothing out, so the whole scope stands.
        return options[:exclude].present? ? all : none if tag_list.empty?

        ::MakeTaggable::Taggable::TaggedWithQuery.build(self, MakeTaggable::Tag, MakeTaggable::Tagging, tag_list, options)
      end

      def is_taggable?
        true
      end

      ##
      # The module the generated `<context>_list` methods are defined on, so a model can override
      # one and call `super`.
      #
      # @return [Module]
      #
      def taggable_mixin
        @taggable_mixin ||= Module.new
      end
    end

    # all column names are necessary for PostgreSQL group clause
    def grouped_column_names_for(object)
      self.class.grouped_column_names_for(object)
    end

    ##
    # Contexts this record has been tagged in beyond those the model declares.
    #
    # @return [Array<String>]
    #
    def custom_contexts
      @custom_contexts ||= taggings.map(&:context).uniq
    end

    def is_taggable?
      self.class.is_taggable?
    end

    ##
    # Records a context the model does not declare, so it takes part in saving and reloading.
    #
    # @param value [Symbol, String] the context
    # @return [Array<String>, NilClass]
    #
    def add_custom_context(value)
      custom_contexts << value.to_s unless custom_contexts.include?(value.to_s) || self.class.tag_types.map(&:to_s).include?(value.to_s)
    end

    ##
    # The rendered tag list held in this context's caching column, if the model has one.
    #
    # @param context [Symbol, String] the tagging context
    # @return [String, NilClass]
    #
    def cached_tag_list_on(context)
      self["cached_#{context.to_s.singularize}_list"]
    end

    ##
    # Whether a context's tag list has been loaded or assigned on this record.
    #
    # @param context [Symbol, String] the tagging context
    # @return [TrueClass, FalseClass, MakeTaggable::TagList]
    #
    def tag_list_cache_set_on(context)
      variable_name = "@#{context.to_s.singularize}_list"
      instance_variable_defined?(variable_name) && instance_variable_get(variable_name)
    end

    ##
    # A context's tag list, loading it from the caching column or the database as needed.
    #
    # @param context [Symbol, String] the tagging context
    # @return [MakeTaggable::TagList]
    #
    def tag_list_cache_on(context)
      variable_name = "@#{context.to_s.singularize}_list"
      if instance_variable_get(variable_name)
        instance_variable_get(variable_name)
      elsif cached_tag_list_on(context) && ensure_included_cache_methods! && self.class.caching_tag_list_on?(context)
        instance_variable_set(variable_name, MakeTaggable.default_parser.new(cached_tag_list_on(context)).parse)
      else
        instance_variable_set(variable_name, MakeTaggable::TagList.new(tags_on(context).map(&:name)))
      end
    end

    ##
    # A context's tag list, covering contexts the model does not declare.
    #
    # Only unowned tags appear here. Use {#all_tags_list_on} to include tags applied by a tagger.
    #
    # @param context [Symbol, String] the tagging context
    # @return [MakeTaggable::TagList]
    #
    # @example
    #   @user.tag_list_on(:customs) # => ["one", "two"]
    #
    def tag_list_on(context)
      add_custom_context(context)
      tag_list_cache_on(context)
    end

    ##
    # A context's tag list including tags applied by a tagger.
    #
    # @param context [Symbol, String] the tagging context
    # @return [MakeTaggable::TagList] frozen
    #
    def all_tags_list_on(context)
      variable_name = "@all_#{context.to_s.singularize}_list"
      return instance_variable_get(variable_name) if instance_variable_defined?(variable_name) && instance_variable_get(variable_name)

      instance_variable_set(variable_name, MakeTaggable::TagList.new(all_tags_on(context).map(&:name)).freeze)
    end

    ##
    # Returns all tags of a given context
    def all_tags_on(context)
      tagging_table_name = MakeTaggable::Tagging.table_name

      opts = ["#{tagging_table_name}.context = ?", context.to_s]
      scope = base_tags.where(opts)

      if MakeTaggable::Utils.using_postgresql?
        group_columns = grouped_column_names_for(MakeTaggable::Tag)
        scope.order(Arel.sql("max(#{tagging_table_name}.created_at)")).group(group_columns)
      else
        scope.group("#{MakeTaggable::Tag.table_name}.#{MakeTaggable::Tag.primary_key}")
      end.to_a
    end

    ##
    # Returns all tags that are not owned of a given context
    def tags_on(context)
      scope = base_tags.where(["#{MakeTaggable::Tagging.table_name}.context = ? AND #{MakeTaggable::Tagging.table_name}.tagger_id IS NULL", context.to_s])
      # when preserving tag order, return tags in created order
      # if we added the order to the association this would always apply
      scope = scope.order("#{MakeTaggable::Tagging.table_name}.id") if self.class.preserve_tag_order?
      scope
    end

    ##
    # Replaces a context's tag list, covering contexts the model does not declare. Saved with the
    # record.
    #
    # @param context [Symbol, String] the tagging context
    # @param new_list [String, Array<String>] the tags to apply
    # @return [MakeTaggable::TagList]
    #
    # @example
    #   @user.set_tag_list_on(:customs, "same, as, tag, list")
    #   @user.save
    #
    def set_tag_list_on(context, new_list)
      add_custom_context(context)

      variable_name = "@#{context.to_s.singularize}_list"

      parsed_new_list = MakeTaggable.default_parser.new(new_list).parse

      instance_variable_set(variable_name, parsed_new_list)
    end

    ##
    # Every context this record tags in, declared and dynamic alike.
    #
    # @return [Array<String>]
    #
    def tagging_contexts
      self.class.tag_types.map(&:to_s) + custom_contexts
    end

    ##
    # Reloads the record, discarding the tag lists held in memory.
    #
    # @param args [Array<Object>] arguments forwarded to Active Record
    # @return [ActiveRecord::Base] self
    #
    def reload(*args)
      self.class.tag_types.each do |context|
        instance_variable_set("@#{context.to_s.singularize}_list", nil)
        instance_variable_set("@all_#{context.to_s.singularize}_list", nil)
      end

      super
    end

    ##
    # Find existing tags or create non-existing tags
    def load_tags(tag_list)
      MakeTaggable::Tag.find_or_create_all_with_like_by_name(tag_list)
    end

    ##
    # Writes every assigned tag list to the database. Runs after save.
    #
    # @return [TrueClass]
    #
    def save_tags
      tagging_contexts.each do |context|
        next unless tag_list_cache_set_on(context)

        # List of currently assigned tag names
        tag_list = tag_list_cache_on(context).uniq

        # Find existing tags or create non-existing tags:
        tags = find_or_create_tags_from_list_with_context(tag_list, context)

        # Tag objects for currently assigned tags
        current_tags = tags_on(context)

        # Tag maintenance based on whether preserving the created order of tags
        if self.class.preserve_tag_order?
          old_tags, new_tags = current_tags - tags, tags - current_tags

          shared_tags = current_tags & tags

          if shared_tags.any? && tags[0...shared_tags.size] != shared_tags
            index = shared_tags.each_with_index { |_, i| break i unless shared_tags[i] == tags[i] }

            # Update arrays of tag objects
            old_tags |= current_tags[index...current_tags.size]
            new_tags |= current_tags[index...current_tags.size] & shared_tags

            # Order the array of tag objects to match the tag list
            new_tags = tags.map { |t|
              new_tags.find { |n| n.name.downcase == t.name.downcase }
            }.compact
          end
        else
          # Delete discarded tags and create new tags
          old_tags = current_tags - tags
          new_tags = tags - current_tags
        end

        # Destroy old taggings:
        if old_tags.present?
          taggings.not_owned.by_context(context).where(tag_id: old_tags).destroy_all
        end

        # Create new taggings:
        new_tags.each do |tag|
          taggings.create!(tag_id: tag.id, context: context.to_s, taggable: self)
        end
      end

      true
    end

    private

    def ensure_included_cache_methods!
      self.class.columns
    end

    # Filters the tag lists from the attribute names.
    def attributes_for_update(attribute_names)
      tag_lists = tag_types.map { |tags_type| "#{tags_type.to_s.singularize}_list" }
      super.delete_if { |attr| tag_lists.include? attr }
    end

    # Filters the tag lists from the attribute names.
    def attributes_for_create(attribute_names)
      tag_lists = tag_types.map { |tags_type| "#{tags_type.to_s.singularize}_list" }
      super.delete_if { |attr| tag_lists.include? attr }
    end

    ##
    # Finds or creates the tag records for a list, given the context they are being applied in.
    #
    # Override it to keep a separate vocabulary for one context by returning tags from a
    # {MakeTaggable::Tag} subclass.
    #
    # @example A separate Tag subclass for one context
    #   class Company < ActiveRecord::Base
    #     make_taggable :markets, :locations
    #
    #     private
    #
    #     def find_or_create_tags_from_list_with_context(tag_list, context)
    #       if context.to_sym == :markets
    #         MarketTag.find_or_create_all_with_like_by_name(tag_list)
    #       else
    #         super
    #       end
    #     end
    #   end
    #
    # @param tag_list [Array<String>] the tags to find or create
    # @param _context [Symbol] the context the tags are being applied in
    # @return [Array<MakeTaggable::Tag>]
    #
    def find_or_create_tags_from_list_with_context(tag_list, _context)
      load_tags(tag_list)
    end
  end
end
