# frozen_string_literal: true

module MakeTaggable::Taggable::TaggedWithQuery
  ##
  # Shared Arel plumbing for the three query strategies.
  #
  # @api private
  #
  class QueryBase
    ##
    # @param taggable_model [Class] the model being queried
    # @param tag_model [Class] the tag model
    # @param tagging_model [Class] the tagging model
    # @param tag_list [MakeTaggable::TagList] the tags to match
    # @param options [Hash] the options given to `tagged_with`
    # @return [MakeTaggable::Taggable::TaggedWithQuery::QueryBase]
    #
    def initialize(taggable_model, tag_model, tagging_model, tag_list, options)
      @taggable_model = taggable_model
      @tag_model = tag_model
      @tagging_model = tagging_model
      @tag_list = tag_list
      @options = options
    end

    private

    attr_reader :taggable_model, :tag_model, :tagging_model, :tag_list, :options

    def taggable_arel_table
      @taggable_arel_table ||= taggable_model.arel_table
    end

    def tag_arel_table
      @tag_arel_table ||= tag_model.arel_table
    end

    def tagging_arel_table
      @tagging_arel_table ||= tagging_model.arel_table
    end

    def tag_match_type(tag)
      matches_attribute = tag_arel_table[:name]
      matches_attribute = matches_attribute.lower unless MakeTaggable.strict_case_match

      if options[:wild].present?
        matches_attribute.matches("%#{escaped_tag(tag)}%", "!", MakeTaggable.strict_case_match)
      else
        matches_attribute.matches(escaped_tag(tag), "!", MakeTaggable.strict_case_match)
      end
    end

    def tags_match_type
      matches_attribute = tag_arel_table[:name]
      matches_attribute = matches_attribute.lower unless MakeTaggable.strict_case_match

      if options[:wild].present?
        matches_attribute.matches_any(tag_list.map { |tag| "%#{escaped_tag(tag)}%" }, "!", MakeTaggable.strict_case_match)
      else
        matches_attribute.matches_any(tag_list.map { |tag| escaped_tag(tag).to_s }, "!", MakeTaggable.strict_case_match)
      end
    end

    # A condition selecting the taggings that tie a row of the taggable table to
    # one of the tags being matched, narrowed by whichever of :on, :owned_by,
    # :start_at and :end_at were given.
    #
    # It correlates to the taggable table, so it only means anything inside a
    # subquery -- an EXISTS test, or a COUNT used for ordering.
    def matching_taggings
      condition = tagging_arel_table[:taggable_id].eq(taggable_arel_table[taggable_model.primary_key])
        .and(tagging_arel_table[:taggable_type].eq(taggable_model.base_class.name))
        .and(
          tagging_arel_table[:tag_id].in(
            tag_arel_table.project(tag_arel_table[:id]).where(tags_match_type)
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

    # Orders by how many of the matched taggings a row has, most first.
    def matching_tag_count_order
      "(SELECT count(*) FROM #{tagging_model.table_name} WHERE #{matching_taggings.to_sql}) desc"
    end

    def escaped_tag(tag)
      tag = tag.downcase unless MakeTaggable.strict_case_match
      MakeTaggable::Utils.escape_like(tag)
    end

    def adjust_taggings_alias(taggings_alias)
      if taggings_alias.size > 75
        taggings_alias = "taggings_alias_" + Digest::SHA1.hexdigest(taggings_alias)
      end
      taggings_alias
    end
  end
end
