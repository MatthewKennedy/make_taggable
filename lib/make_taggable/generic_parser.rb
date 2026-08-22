# frozen_string_literal: true

module MakeTaggable
  ##
  # The base class for tag parsers, and a working parser in its own right: it splits on commas and
  # ignores surrounding whitespace.
  #
  # Subclass it to accept a different format, and point {MakeTaggable::Configuration#default_parser}
  # at the subclass, or pass it per call as the `:parser` option to {MakeTaggable::TagList#add}.
  #
  # @example A parser splitting on pipes
  #   class PipeParser < MakeTaggable::GenericParser
  #     def parse
  #       MakeTaggable::TagList.new.tap do |tag_list|
  #         tag_list.add @tag_list.split("|")
  #       end
  #     end
  #   end
  #
  class GenericParser
    ##
    # Holds the input until {#parse} is called.
    #
    # @param tag_list [String, Array<String>, MakeTaggable::TagList] the tag input to parse
    # @return [MakeTaggable::GenericParser]
    #
    def initialize(tag_list)
      @tag_list = tag_list
    end

    ##
    # Splits the input on commas.
    #
    # @return [MakeTaggable::TagList] the parsed tags
    #
    # @example
    #   MakeTaggable::GenericParser.new("One , Two, Three").parse # => ["One", "Two", "Three"]
    #
    def parse
      TagList.new.tap do |tag_list|
        tag_list.add @tag_list.split(",").map(&:strip).reject(&:empty?)
      end
    end
  end
end
