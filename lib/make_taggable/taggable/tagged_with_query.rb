# frozen_string_literal: true

require_relative "tagged_with_query/query_base"
require_relative "tagged_with_query/exclude_tags_query"
require_relative "tagged_with_query/any_tags_query"
require_relative "tagged_with_query/all_tags_query"

##
# Builds the relation behind {MakeTaggable::Taggable::Core::ClassMethods#tagged_with}.
#
# @api private
#
module MakeTaggable::Taggable::TaggedWithQuery
  ##
  # Picks the query strategy the options call for and builds the relation.
  #
  # @param taggable_model [Class] the model being queried
  # @param tag_model [Class] the tag model
  # @param tagging_model [Class] the tagging model
  # @param tag_list [MakeTaggable::TagList] the tags to match
  # @param options [Hash] the options given to `tagged_with`
  # @return [ActiveRecord::Relation]
  #
  def self.build(taggable_model, tag_model, tagging_model, tag_list, options)
    if options[:exclude].present? && options[:match_all].present?
      raise ArgumentError,
        ":match_all and :exclude cannot be combined. :match_all selects records carrying only the " \
        "given tags and nothing else, :exclude selects records carrying none of them, and there is " \
        "no set of records that satisfies both."
    end

    if options[:exclude].present?
      ExcludeTagsQuery.new(taggable_model, tag_model, tagging_model, tag_list, options).build
    elsif options[:any].present?
      AnyTagsQuery.new(taggable_model, tag_model, tagging_model, tag_list, options).build
    else
      AllTagsQuery.new(taggable_model, tag_model, tagging_model, tag_list, options).build
    end
  end
end
