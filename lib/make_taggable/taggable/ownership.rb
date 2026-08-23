# frozen_string_literal: true

module MakeTaggable::Taggable
  ##
  # Tags applied by a tagger, kept separate from the record's own tags.
  #
  # Owned tags do not appear in `tag_list`, which only ever returns unowned tags. Use
  # `all_tags_list` to see both together.
  #
  # @see MakeTaggable::Tagger
  #
  module Ownership
    ##
    # @param base [Class] the model being made taggable
    # @return [void]
    #
    # @api private
    #
    def self.included(base)
      base.extend MakeTaggable::Taggable::Ownership::ClassMethods

      base.class_eval do
        after_save :save_owned_tags
      end

      base.initialize_make_taggable_ownership
    end

    ##
    # Added to every taggable model.
    #
    module ClassMethods
      ##
      # Adds contexts and refreshes the ownership readers.
      #
      # @param args [Array<Symbol, String>] the contexts to add
      # @return [void]
      #
      def make_taggable(*args)
        initialize_make_taggable_ownership
        super
      end

      ##
      # Defines a `<context>_from(owner)` reader for each context.
      #
      # @return [void]
      #
      def initialize_make_taggable_ownership
        tag_types.map(&:to_s).each do |tag_type|
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def #{tag_type}_from(owner)
              owner_tag_list_on(owner, '#{tag_type}')
            end
          RUBY
        end
      end
    end

    ##
    # This record's tags belonging to one owner, across every context.
    #
    # @param owner [ActiveRecord::Base, NilClass] the tagger, or `nil` for every tag on the record
    # @return [ActiveRecord::Relation]
    #
    def owner_tags(owner)
      scope = if owner.nil?
        base_tags
      else
        base_tags.where(
          MakeTaggable::Tagging.table_name.to_s => {
            tagger_id: owner.id,
            tagger_type: owner.class.base_class.to_s
          }
        )
      end

      # when preserving tag order, return tags in created order
      # if we added the order to the association this would always apply
      if self.class.preserve_tag_order?
        scope.order("#{MakeTaggable::Tagging.table_name}.id")
      else
        scope
      end
    end

    ##
    # This record's tags belonging to one owner, in one context.
    #
    # @param owner [ActiveRecord::Base, NilClass] the tagger, or `nil` for every tag on the record
    # @param context [Symbol, String] the tagging context
    # @return [ActiveRecord::Relation]
    #
    # @example
    #   @photo.owner_tags_on(@user, :locations)
    #
    def owner_tags_on(owner, context)
      owner_tags(owner).where(
        MakeTaggable::Tagging.table_name.to_s => {
          context: context
        }
      )
    end

    ##
    # The per-owner tag lists held in memory for a context, keyed by owner.
    #
    # @param context [Symbol, String] the tagging context
    # @return [Hash{ActiveRecord::Base => MakeTaggable::TagList}]
    #
    def cached_owned_tag_list_on(context)
      variable_name = "@owned_#{context}_list"
      (instance_variable_defined?(variable_name) && instance_variable_get(variable_name)) || instance_variable_set(variable_name, {})
    end

    ##
    # One owner's tag list for a context.
    #
    # @param owner [ActiveRecord::Base] the tagger
    # @param context [Symbol, String] the tagging context
    # @return [MakeTaggable::TagList]
    #
    def owner_tag_list_on(owner, context)
      add_custom_context(context)

      cache = cached_owned_tag_list_on(context)

      cache[owner] ||= MakeTaggable::TagList.new(*owner_tags_on(owner, context).map(&:name))
    end

    ##
    # Replaces one owner's tag list for a context. Saved with the record.
    #
    # @param owner [ActiveRecord::Base] the tagger
    # @param context [Symbol, String] the tagging context
    # @param new_list [String, Array<String>] the tags to apply
    # @return [MakeTaggable::TagList]
    #
    def set_owner_tag_list_on(owner, context, new_list)
      add_custom_context(context)

      cache = cached_owned_tag_list_on(context)

      cache[owner] = MakeTaggable.default_parser.new(new_list).parse
    end

    ##
    # Reloads the record, discarding the owned tag lists held in memory.
    #
    # @param args [Array<Object>] arguments forwarded to Active Record
    # @return [ActiveRecord::Base] self
    #
    def reload(*args)
      self.class.tag_types.each do |context|
        instance_variable_set("@owned_#{context}_list", nil)
      end

      super
    end

    ##
    # Writes every owner's tag lists to the database. Runs after save.
    #
    # @return [TrueClass]
    #
    def save_owned_tags
      assigned_tagging_contexts.each do |context|
        cached_owned_tag_list_on(context).each do |owner, tag_list|
          # Find existing tags or create non-existing tags:
          tags = find_or_create_tags_from_list_with_context(tag_list.uniq, context)

          # Tag objects for owned tags
          owned_tags = owner_tags_on(owner, context).to_a

          # Tag maintenance based on whether preserving the created order of tags
          if self.class.preserve_tag_order?
            old_tags, new_tags = owned_tags - tags, tags - owned_tags

            shared_tags = owned_tags & tags

            if shared_tags.any? && tags[0...shared_tags.size] != shared_tags
              index = shared_tags.each_with_index { |_, i| break i unless shared_tags[i] == tags[i] }

              # Update arrays of tag objects
              old_tags |= owned_tags.from(index)
              new_tags |= owned_tags.from(index) & shared_tags

              # Order the array of tag objects to match the tag list
              new_tags = tags.map { |t| new_tags.find { |n| n.name.downcase == t.name.downcase } }.compact
            end
          else
            # Delete discarded tags and create new tags
            old_tags = owned_tags - tags
            new_tags = tags - owned_tags
          end

          # Find all taggings that belong to the taggable (self), are owned by the owner,
          # have the correct context, and are removed from the list.
          if old_tags.present?
            MakeTaggable::Tagging.where(taggable_id: id, taggable_type: self.class.base_class.to_s,
              tagger_type: owner.class.base_class.to_s, tagger_id: owner.id,
              tag_id: old_tags, context: context).destroy_all
          end

          # Create new taggings, in a consistent order -- see the note in
          # Core#save_tags on why the order matters.
          new_tags = new_tags.sort_by(&:id) unless self.class.preserve_tag_order?

          new_tags.each do |tag|
            taggings.create!(tag_id: tag.id, context: context.to_s, tagger: owner, taggable: self)
          end
        end
      end

      true
    end
  end
end
