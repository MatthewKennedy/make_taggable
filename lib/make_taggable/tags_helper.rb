# frozen_string_literal: true

module MakeTaggable
  ##
  # View helpers for rendering tags. Mixed into Action View automatically.
  #
  module TagsHelper
    ##
    # Yields each tag with the CSS class matching how often it is used, for building a tag cloud.
    #
    # Classes are handed out in the order given, from least to most used, so the first class is the
    # smallest and the last is the largest.
    #
    # @param tags [Array<MakeTaggable::Tag>] tags carrying a `taggings_count`
    # @param classes [Array<String>] the CSS classes, smallest first
    # @yieldparam tag [MakeTaggable::Tag] the tag
    # @yieldparam css_class [String] the class for that tag's frequency
    # @return [Array] the tags, or an empty array when none were given
    #
    # @example
    #   <% tag_cloud(@tags, %w[css1 css2 css3 css4]) do |tag, css_class| %>
    #     <%= link_to tag.name, tag_path(tag.name), class: css_class %>
    #   <% end %>
    #
    def tag_cloud(tags, classes)
      return [] if tags.empty?

      max_count = tags.max_by(&:taggings_count).taggings_count.to_f

      tags.each do |tag|
        index = ((tag.taggings_count / max_count) * (classes.size - 1))
        yield tag, classes[index.nan? ? 0 : index.round]
      end
    end
  end
end
