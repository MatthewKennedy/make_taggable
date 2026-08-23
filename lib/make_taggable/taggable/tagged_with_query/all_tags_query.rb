# frozen_string_literal: true

module MakeTaggable::Taggable::TaggedWithQuery
  ##
  # Records carrying every tag in the list.
  #
  # @api private
  #
  class AllTagsQuery < QueryBase
    ##
    # @return [ActiveRecord::Relation]
    #
    def build
      taggable_model.joins(match_all_join)
        .where(carries_every_tag)
        .group(by_taggable)
        .having(tags_that_matches_count)
        .order(Arel.sql(order_conditions))
        .readonly(false)
    end

    private

    # One EXISTS test per tag, rather than one join per tag.
    #
    # A join multiplies the result: a record is returned once for every tagging
    # that satisfies it, so a tag applied in two contexts, or a wild pattern
    # matching two of a record's tags, returned that record twice. EXISTS asks
    # the question the query is actually asking -- does this record carry the
    # tag -- and answers it once.
    def carries_every_tag
      tag_list.map { |tag| taggings_for(tag).exists }.inject(:and)
    end

    def taggings_for(tag)
      tagging_arel_table
        .project(Arel.star)
        .where(tag_conditions(tag))
    end

    def tag_conditions(tag)
      condition = tagging_arel_table[:taggable_id].eq(taggable_arel_table[taggable_model.primary_key])
        .and(tagging_arel_table[:taggable_type].eq(taggable_model.base_class.name))
        .and(
          tagging_arel_table[:tag_id].in(
            tag_arel_table.project(tag_arel_table[:id]).where(tag_match_type(tag))
          )
        )

      if options[:start_at].present?
        condition = condition.and(tagging_arel_table[:created_at].gteq(options[:start_at]))
      end

      if options[:end_at].present?
        condition = condition.and(tagging_arel_table[:created_at].lteq(options[:end_at]))
      end

      if options[:on].present?
        condition = condition.and(tagging_arel_table[:context].eq(options[:on]))
      end

      if (owner = options[:owned_by]).present?
        condition = condition.and(tagging_arel_table[:tagger_id].eq(owner.id))
          .and(tagging_arel_table[:tagger_type].eq(owner.class.base_class.to_s))
      end

      condition
    end

    # :match_all keeps its outer join. It counts a record's taggings and compares
    # that to the number of tags matched, so it needs them joined -- and the
    # GROUP BY it already carries collapses the duplicates a join would cause.
    def match_all_join
      return [] unless options[:match_all].present?

      taggable_arel_table
        .join(tagging_arel_table, Arel::Nodes::OuterJoin)
        .on(match_all_on_conditions)
        .join_sources
    end

    def match_all_on_conditions
      on_condition = tagging_arel_table[:taggable_id].eq(taggable_arel_table[taggable_model.primary_key])
        .and(tagging_arel_table[:taggable_type].eq(taggable_model.base_class.name))

      if options[:start_at].present?
        on_condition = on_condition.and(tagging_arel_table[:created_at].gteq(options[:start_at]))
      end

      if options[:end_at].present?
        on_condition = on_condition.and(tagging_arel_table[:created_at].lteq(options[:end_at]))
      end

      if options[:on].present?
        on_condition = on_condition.and(tagging_arel_table[:context].eq(options[:on]))
      end

      on_condition
    end

    def by_taggable
      return [] unless options[:match_all].present?

      taggable_arel_table[taggable_model.primary_key]
    end

    def tags_that_matches_count
      return [] unless options[:match_all].present?

      taggable_model.find_by_sql(tag_arel_table.project(Arel.star.count).where(tags_match_type).to_sql)

      tagging_arel_table[:taggable_id].count.eq(
        tag_arel_table.project(Arel.star.count).where(tags_match_type)
      )
    end

    def order_conditions
      order_by = []

      # The old expression here counted every tagging in the table, correlated
      # to nothing, and asked for COUNT(taggings.*) while doing it -- invalid
      # SQL that ordered nothing even where it parsed. The shared correlated
      # count is what the :any strategy has always used.
      if options[:order_by_matching_tag_count].present? && options[:match_all].blank?
        order_by << matching_tag_count_order
      end

      order_by << options[:order] if options[:order].present?
      order_by.join(", ")
    end
  end
end
