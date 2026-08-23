# frozen_string_literal: true

module MakeTaggable::Taggable::TaggedWithQuery
  ##
  # Records carrying none of the tags in the list.
  #
  # @api private
  #
  class ExcludeTagsQuery < QueryBase
    ##
    # @return [ActiveRecord::Relation]
    #
    def build
      taggable_model.joins(owning_to_tagger)
        .where(tags_not_in_list)
        .readonly(false)
    end

    private

    def tags_not_in_list
      on_condition = tagging_arel_table[:tag_id].eq(tag_arel_table[:id])
        .and(tagging_arel_table[:taggable_type].eq(taggable_model.base_class.name))
        .and(tags_match_type)

      # Every option below narrows which taggings count as "carrying the tag".
      # Left off, the subquery gathers taggings from other contexts and other
      # times, and excludes records on the strength of them.
      if options[:on].present?
        on_condition = on_condition.and(context_predicate)
      end

      if options[:start_at].present?
        on_condition = on_condition.and(tagging_arel_table[:created_at].gteq(options[:start_at]))
      end

      if options[:end_at].present?
        on_condition = on_condition.and(tagging_arel_table[:created_at].lteq(options[:end_at]))
      end

      taggable_arel_table[taggable_model.primary_key].not_in(
        tagging_arel_table
          .project(tagging_arel_table[:taggable_id])
          .join(tag_arel_table)
          .on(on_condition)
      )
    end

    def owning_to_tagger
      return [] unless options[:owned_by].present?

      owner = options[:owned_by]

      arel_join = taggable_arel_table
        .join(tagging_arel_table)
        .on(
          tagging_arel_table[:tagger_id].eq(owner.id)
          .and(tagging_arel_table[:tagger_type].eq(owner.class.base_class.to_s))
          .and(tagging_arel_table[:taggable_id].eq(taggable_arel_table[taggable_model.primary_key]))
          .and(tagging_arel_table[:taggable_type].eq(taggable_model.base_class.name))
        )

      arel_join.join_sources
    end
  end
end
