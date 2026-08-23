# frozen_string_literal: true

module MakeTaggable::Taggable::TaggedWithQuery
  ##
  # Records carrying at least one tag in the list.
  #
  # @api private
  #
  class AnyTagsQuery < QueryBase
    ##
    # @return [ActiveRecord::Relation]
    #
    def build
      # No select of our own. This strategy filters with an EXISTS subquery and
      # joins nothing, so Active Record's default select list is already right.
      # Forcing `taggable_models.*` made COUNT() invalid and left a caller's own
      # select appended after the star rather than replacing it.
      taggable_model
        .where(model_has_matching_taggings)
        .order(Arel.sql(order_conditions))
        .readonly(false)
    end

    private

    def model_has_matching_taggings
      tagging_arel_table.project(Arel.star).where(matching_taggings).exists
    end

    def order_conditions
      order_by = []
      if options[:order_by_matching_tag_count].present?
        order_by << matching_tag_count_order
      end

      order_by << options[:order] if options[:order].present?
      order_by.join(", ")
    end

    def alias_name(tag_list)
      alias_base_name = taggable_model.base_class.name.downcase
      taggings_context = options[:on] ? "_#{options[:on]}" : ""

      adjust_taggings_alias(
        "#{alias_base_name[0..4]}#{taggings_context[0..6]}_taggings_#{MakeTaggable::Utils.sha_prefix(tag_list.join("_"))}"
      )
    end
  end
end
