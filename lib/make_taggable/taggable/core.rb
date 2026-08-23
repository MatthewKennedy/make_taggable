# frozen_string_literal: true

require_relative "tagged_with_query"

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
              class_name: MakeTaggable.tag_class,
              through: context_taggings,
              source: :tag
          end

          taggable_mixin.class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def #{tag_type}_list
              tag_list_on('#{tags_type}')
            end

            def #{tag_type}_list=(new_tags)
              set_tag_list_on('#{tags_type}', new_tags)
            end

            def all_#{tags_type}_list
              all_tags_list_on('#{tags_type}')
            end

            def #{tag_type}_list_changed?
              tag_list_changed_on?('#{tags_type}')
            end

            def #{tag_type}_list_was
              tag_list_was_on('#{tags_type}')
            end

            def #{tag_type}_list_change
              tag_list_change_on('#{tags_type}')
            end

            def will_save_change_to_#{tag_type}_list?
              tag_list_changed_on?('#{tags_type}')
            end

            def saved_change_to_#{tag_type}_list
              saved_tag_list_changes['#{tag_type}_list']
            end

            def saved_change_to_#{tag_type}_list?
              saved_tag_list_changes.key?('#{tag_type}_list')
            end

            private
            def dirtify_tag_list(tagging)
              tag_list_changed_by_association(tagging.context)
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

      ##
      # Every column on a table, qualified, joined for a `GROUP BY` clause.
      #
      # Nothing in the library needs this any more. PostgreSQL wanted every selected
      # non-aggregated column in the `GROUP BY` before 9.1; since then the primary key is enough,
      # and that is what the library groups by. Kept because it is public and useful for building
      # such a clause by hand.
      #
      # @param object [Class] the model whose columns to list
      # @return [String]
      #
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
      # @option options [TrueClass, FalseClass] :order_by_matching_tag_count order by how many
      #   matching taggings a record has, most first. No effect alongside `:match_all`
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

    ##
    # @see ClassMethods#grouped_column_names_for
    #
    # @param object [Class] the model whose columns to list
    # @return [String]
    #
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
      # The declared contexts are checked first deliberately. Ruby evaluates the
      # left operand of `||` first, so testing custom_contexts up front loaded
      # every tagging on the record just to assign a list on an ordinary
      # declared context.
      return if self.class.tag_types.map(&:to_s).include?(value.to_s)

      custom_contexts << value.to_s unless custom_contexts.include?(value.to_s)
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
    # The tag lists as they stood when the record was loaded or last saved, keyed by context.
    #
    # @return [Hash{String => Array<String>}]
    #
    # @api private
    #
    def original_tag_lists
      @original_tag_lists ||= {}
    end

    ##
    # Records what a context's list looked like before anything touched it, if that has not been
    # noted already. Called before every change, so the first note wins and later ones are ignored.
    #
    # @param context [Symbol, String] the tagging context
    # @return [void]
    #
    # @api private
    #
    def note_tag_list_original(context)
      key = context.to_s
      return if original_tag_lists.key?(key)

      original_tag_lists[key] = tag_list_cache_on(key).to_a.dup
    end

    ##
    # Notes the original list and drops the cached one, after a tagging was added or removed
    # through the association rather than through a list.
    #
    # The cached list is what `tag_list_on` answers from, and pushing onto `record.tags` does not
    # go near it -- so without dropping it the list before and after compare equal and nothing
    # looks changed.
    #
    # @param context [Symbol, String] the tagging context
    # @return [void]
    #
    # @api private
    #
    def tag_list_changed_by_association(context)
      note_tag_list_original(context)

      singular = context.to_s.singularize
      instance_variable_set("@#{singular}_list", nil)
      instance_variable_set("@all_#{singular}_list", nil)
    end

    ##
    # Whether a context's list differs from the one loaded or last saved.
    #
    # Order counts only where the model asked for it with `make_ordered_taggable`.
    #
    # @param context [Symbol, String] the tagging context
    # @return [TrueClass, FalseClass]
    #
    def tag_list_changed_on?(context)
      key = context.to_s
      return false unless original_tag_lists.key?(key)

      comparable_tag_list(original_tag_lists[key]) != comparable_tag_list(tag_list_on(key))
    end

    ##
    # A context's list as it stood when the record was loaded or last saved.
    #
    # @param context [Symbol, String] the tagging context
    # @return [Array<String>]
    #
    def tag_list_was_on(context)
      key = context.to_s

      original_tag_lists.key?(key) ? original_tag_lists[key] : tag_list_on(key).to_a
    end

    ##
    # A context's list before and after, or `nil` when it has not changed.
    #
    # @param context [Symbol, String] the tagging context
    # @return [Array<Array<String>>, NilClass]
    #
    def tag_list_change_on(context)
      return unless tag_list_changed_on?(context)

      [tag_list_was_on(context), tag_list_on(context).to_a]
    end

    ##
    # The tag list changes this record is carrying, keyed the way Active Model keys `changes`.
    #
    # @return [Hash{String => Array<Array<String>>}]
    #
    # @api private
    #
    def tag_list_changes
      # assigned_tagging_contexts, not tagging_contexts: the latter reads the
      # taggings table to find contexts used previously, and a record only has
      # pending changes in contexts it holds a list for.
      assigned_tagging_contexts.each_with_object({}) do |context, changes|
        change = tag_list_change_on(context)
        changes["#{context.to_s.singularize}_list"] = change if change
      end
    end

    ##
    # The tag list changes written by the most recent save.
    #
    # @return [Hash{String => Array<Array<String>>}]
    #
    # @api private
    #
    def saved_tag_list_changes
      @saved_tag_list_changes ||= {}
    end

    ##
    # Active Model's changes, plus the tag lists.
    #
    # @return [ActiveSupport::HashWithIndifferentAccess]
    #
    def changes
      super.merge(tag_list_changes)
    end

    ##
    # @return [Hash] the previous values of everything changed, tag lists included
    #
    def changed_attributes
      super.merge(tag_list_changes.transform_values(&:first))
    end

    ##
    # @return [TrueClass, FalseClass] whether anything changed, tag lists included
    #
    def changed?
      super || tag_list_changes.any?
    end

    ##
    # @return [Hash] the changes the last save wrote, tag lists included
    #
    def saved_changes
      super.merge(saved_tag_list_changes)
    end

    ##
    # A context's tag list, loading it from the caching column or the database as needed.
    #
    # @param context [Symbol, String] the tagging context
    # @return [MakeTaggable::TagList]
    #
    def tag_list_cache_on(context)
      variable_name = "@#{context.to_s.singularize}_list"
      return instance_variable_get(variable_name) if instance_variable_get(variable_name)

      list =
        if cached_tag_list_on(context) && ensure_included_cache_methods! && self.class.caching_tag_list_on?(context)
          MakeTaggable.default_parser.new(cached_tag_list_on(context)).parse
        else
          MakeTaggable::TagList.new(unowned_tag_names_on(context))
        end

      # Note what was there the first time the list is built, before anything
      # can have touched it. A caller holding this list can mutate it in place
      # -- tag_list.add("x") -- which never goes through the writer, so this is
      # the only chance to see the original.
      original_tag_lists[context.to_s] ||= list.to_a.dup

      instance_variable_set(variable_name, list)
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

      group_columns = "#{MakeTaggable::Tag.table_name}.#{MakeTaggable::Tag.primary_key}"

      if MakeTaggable::Utils.using_postgresql?
        # Ordering by an aggregate is why this groups at all. Grouping by the
        # primary key alone is enough on every supported PostgreSQL -- it works
        # the functional dependency out itself, and has since 9.1.
        scope.order(Arel.sql("max(#{tagging_table_name}.created_at)")).group(group_columns)
      else
        scope.group(group_columns)
      end.to_a
    end

    ##
    # The names of a context's unowned tags, read from the preloaded taggings where they are
    # available and queried where they are not.
    #
    # `includes(:tags)` loads the per-context taggings association as well as the tags themselves,
    # and those taggings carry `tagger_id` -- which is what makes them usable here, since the list
    # excludes owned tags and the tags association alone cannot say which are owned.
    #
    # @param context [Symbol, String] the tagging context
    # @return [Array<String>]
    #
    # @api private
    #
    def unowned_tag_names_on(context)
      preloaded = preloaded_taggings_on(context)
      return tags_on(context).map(&:name) unless preloaded

      preloaded.map { |tagging| tagging.tag.name }
    end

    ##
    # A context's taggings if they are already in memory, otherwise `nil`.
    #
    # Only unowned taggings are returned, in tagging order where the model preserves it, so the
    # result matches what {#tags_on} would have queried.
    #
    # @param context [Symbol, String] the tagging context
    # @return [Array<MakeTaggable::Tagging>, NilClass]
    #
    # @api private
    #
    def preloaded_taggings_on(context)
      name = :"#{context.to_s.singularize}_taggings"
      return unless self.class.reflect_on_association(name)

      association = association(name)
      return unless association.loaded?

      taggings = association.target.reject(&:tagger_id)
      self.class.preserve_tag_order? ? taggings.sort_by(&:id) : taggings
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

      # Before the list is replaced, so the note captures what was there rather
      # than what is being put there.
      note_tag_list_original(context)

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
    # The contexts a save has to consider: the declared ones, plus any context this record has
    # been handed a list for in memory.
    #
    # Deliberately not {#tagging_contexts}, which reads the taggings table to find contexts used
    # previously. A save only writes lists held in memory, so the ones already loaded are the only
    # ones that can have anything to write -- and reading the table on every save cost a query
    # whether or not any tag changed, and broke `strict_loading` outright.
    #
    # @return [Array<String>]
    #
    # @api private
    #
    def assigned_tagging_contexts
      self.class.tag_types.map(&:to_s) + (@custom_contexts || [])
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
      MakeTaggable.tag_model.find_or_create_all_with_like_by_name(tag_list)
    end

    ##
    # Writes every assigned tag list to the database. Runs after save.
    #
    # @return [TrueClass]
    #
    def save_tags
      assigned_tagging_contexts.each do |context|
        next unless tag_list_cache_set_on(context)

        # List of currently assigned tag names
        tag_list = tag_list_cache_on(context).uniq

        # Find existing tags or create non-existing tags:
        tags = find_or_create_tags_from_list_with_context(tag_list, context)

        # A tag that failed its own validation comes back unsaved, with a nil
        # id. Left alone it reaches taggings.create! as `tag_id: nil`, and the
        # caller is told "Tag can't be blank" -- the wrong attribute, and no
        # sign of what was actually wrong. Report the tag itself instead.
        unsaved = tags.reject(&:persisted?)
        raise ActiveRecord::RecordInvalid.new(unsaved.first) if unsaved.any?

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

        # Create new taggings, in a consistent order. Each insert bumps the tag's
        # counter cache, so two concurrent saves touching the same tags would
        # otherwise take row locks in whatever order their lists happened to be
        # in, and deadlock. Ordering is skipped where the model asked for tag
        # order to be preserved, since there the creation order is the point.
        new_tags = new_tags.sort_by(&:id) unless self.class.preserve_tag_order?

        new_tags.each do |tag|
          taggings.create!(tag_id: tag.id, context: context.to_s, taggable: self)
        end
      end

      settle_tag_list_changes

      true
    end

    # Moves the pending tag list changes into the saved ones, so that after a
    # save the record reports what the save wrote rather than what it was about
    # to write. Mirrors what Active Model does for real attributes.
    def settle_tag_list_changes
      @saved_tag_list_changes = tag_list_changes
      original_tag_lists.clear
    end

    private

    def comparable_tag_list(list)
      self.class.preserve_tag_order? ? list.to_a : list.to_a.sort
    end

    def ensure_included_cache_methods!
      self.class.columns
    end

    ##
    # Finds or creates the tag records for a list, given the context they are being applied in.
    #
    # Override it to resolve one context's names through a different class -- one with its own
    # validations or callbacks, say.
    #
    # This routes creation only. Reading gives back whatever {MakeTaggable.tag_class} names, and
    # without a `type` column on the tags table there is nothing to tell a subclass's rows apart, so
    # the vocabularies are not actually separate. See `docs/contexts.md` for the column to add if
    # that is what you are after, and {MakeTaggable.tag_class} for changing the class globally.
    #
    # @example Resolving one context's names through another class
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
