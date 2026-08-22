# frozen_string_literal: true

module MakeTaggable
  ##
  # The join between a tag and the record it was applied to.
  #
  # A tagging records the context the tag was applied in, and optionally the tagger who applied it.
  # Records own their taggings, so destroying a taggable destroys its taggings with it.
  #
  # @!attribute [rw] context
  #   The context the tag was applied in, such as `"skills"`.
  #   @return [String]
  # @!attribute [rw] tag
  #   The tag being applied.
  #   @return [MakeTaggable::Tag]
  # @!attribute [rw] taggable
  #   The record being tagged.
  #   @return [ActiveRecord::Base]
  # @!attribute [rw] tagger
  #   The record that applied the tag, when it was applied by a tagger.
  #   @return [ActiveRecord::Base, NilClass]
  #
  class Tagging < ::ActiveRecord::Base
    ##
    # The context used when none is given.
    #
    # @return [String]
    #
    DEFAULT_CONTEXT = "tags"

    self.table_name = MakeTaggable.taggings_table

    belongs_to :tag, class_name: "::MakeTaggable::Tag", counter_cache: MakeTaggable.tags_counter
    belongs_to :taggable, polymorphic: true

    belongs_to :tagger, polymorphic: true, optional: true

    scope :owned_by, ->(owner) { where(tagger: owner) }
    scope :not_owned, -> { where(tagger_id: nil, tagger_type: nil) }

    scope :by_contexts, ->(contexts) { where(context: contexts || DEFAULT_CONTEXT) }
    scope :by_context, ->(context = DEFAULT_CONTEXT) { by_contexts(context.to_s) }

    validates_presence_of :context
    validates_presence_of :tag_id

    validates_uniqueness_of :tag_id, scope: [:taggable_type, :taggable_id, :context, :tagger_id, :tagger_type]

    after_destroy :remove_unused_tags

    private

    # Destroys the tag this tagging pointed at, if nothing else references it and the library is
    # configured to clean up after itself. Runs after destroy.
    #
    # How "nothing else references it" is established depends on the counter cache. With
    # `tags_counter` on, the count is already on the row and only needs re-reading. With it off
    # there is no count to read, so the taggings are asked directly -- `none?` stops at the first
    # row rather than counting them all.
    #
    # @return [void]
    def remove_unused_tags
      return unless MakeTaggable.remove_unused_tags

      if MakeTaggable.tags_counter
        tag.destroy if tag.reload.taggings_count.zero?
      elsif tag.taggings.reload.none?
        tag.destroy
      end
    end
  end
end
