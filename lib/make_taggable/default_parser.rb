# frozen_string_literal: true

module MakeTaggable
  ##
  # The parser the library uses unless told otherwise.
  #
  # It splits on the configured delimiter, or delimiters, and understands quoting: a tag wrapped in
  # single or double quotes may contain the delimiter itself.
  #
  # @example
  #   MakeTaggable::DefaultParser.new("One , Two,  Three").parse
  #   # => ["One", "Two", "Three"]
  #
  # @example A tag containing the delimiter
  #   MakeTaggable::DefaultParser.new('"Ruby, Rails", Hotwire').parse
  #   # => ["Ruby, Rails", "Hotwire"]
  #
  class DefaultParser < GenericParser
    ##
    # Splits the input into tags, honouring quotes and every configured delimiter.
    #
    # @return [MakeTaggable::TagList] the parsed tags
    #
    def parse
      string = @tag_list

      string = string.join(MakeTaggable.glue) if string.respond_to?(:join)
      TagList.new.tap do |tag_list|
        string = string.to_s.dup

        string.gsub!(double_quote_pattern) do
          # Append the matched tag to the tag list
          tag_list << Regexp.last_match[2]
          # Return the matched delimiter ($3) to replace the matched items
          ""
        end

        string.gsub!(single_quote_pattern) do
          # Append the matched tag ($2) to the tag list
          tag_list << Regexp.last_match[2]
          # Return an empty string to replace the matched items
          ""
        end

        # split the string by the delimiter
        # and add to the tag_list
        tag_list.add(string.split(Regexp.new(delimiter)))
      end
    end

    ##
    # The configured delimiters as a regular expression source, ready to interpolate into a pattern.
    #
    # @return [String]
    #
    # @api private
    #
    def delimiter
      # Delimiters are literal strings, so any regular expression metacharacter
      # they contain has to be escaped before it reaches a pattern. Regexp.union
      # handles both the escaping and the alternation between multiple
      # delimiters.
      Regexp.union(Array(MakeTaggable.delimiter)).source
    end

    ##
    # Matches a double-quoted tag, bounded by the start of the string or a delimiter.
    #
    # @return [Regexp]
    #
    # @api private
    #
    def double_quote_pattern
      /(\A|#{delimiter})\s*"(.*?)"\s*(?=#{delimiter}\s*|\z)/
    end

    ##
    # Matches a single-quoted tag, bounded by the start of the string or a delimiter.
    #
    # @return [Regexp]
    #
    # @api private
    #
    def single_quote_pattern
      /(\A|#{delimiter})\s*'(.*?)'\s*(?=#{delimiter}\s*|\z)/
    end
  end
end
