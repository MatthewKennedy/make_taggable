module Uggle
  ##
  # Returns a new TagList using the given tag string.
  #
  # Example:
  # tag_list = Uggle::GenericParser.new.parse("One , Two, Three")
  # tag_list # ["One", "Two", "Three"]
  class GenericParser
    def initialize(tag_list)
      @tag_list = tag_list
    end

    def parse
      TagList.new.tap do |tag_list|
        tag_list.add @tag_list.split(',').map(&:strip).reject(&:empty?)
      end
    end
  end
end
