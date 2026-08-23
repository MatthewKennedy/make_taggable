# frozen_string_literal: true

require "active_support/core_ext/module/delegation"

module MakeTaggable
  ##
  # The list of tag names held against one context of one record.
  #
  # A tag list is an Array, so everything Array offers works on it. What it adds is parsing, and
  # cleaning: blank entries are dropped, entries are converted to strings and stripped, and
  # duplicates are removed according to the configured case sensitivity.
  #
  # @example
  #   list = MakeTaggable::TagList.new("Fun", "Happy")
  #   list.add("Sad, Lonely", parse: true)
  #   list # => ["Fun", "Happy", "Sad", "Lonely"]
  #
  # @!attribute [rw] owner
  #   The tagger whose tags these are, when the list belongs to an owner.
  #   @return [ActiveRecord::Base, NilClass]
  # @!attribute [rw] parser
  #   The parser used when this list is asked to parse a string.
  #   @return [Class]
  #
  class TagList < Array
    attr_accessor :owner
    attr_writer :parser

    ##
    # Builds a tag list from the given names.
    #
    # @param args [Array<String, Symbol>] the tag names, optionally followed by an options hash
    #   accepted by {#add}
    # @return [MakeTaggable::TagList]
    #
    def initialize(*args)
      add(*args)
    end

    ##
    # The parser this list uses when asked to parse.
    #
    # Falls back to the configured {MakeTaggable.default_parser}, and deliberately does not store
    # it. A stored parser is a Class held in an instance variable, and Psych validates instance
    # variables when dumping, so carrying one made every tag list unserialisable -- `audited`,
    # Active Job arguments and `serialize` columns all refuse it.
    #
    # A parser assigned explicitly is still stored, and a list carrying one is subject to the same
    # limitation.
    #
    # @return [Class]
    #
    def parser
      @parser || MakeTaggable.default_parser
    end

    ##
    # Adds tags to the list, ignoring duplicates and blanks.
    #
    # @param names [Array<String, Symbol>] the tags to add, optionally followed by an options hash
    # @option names [TrueClass, FalseClass] :parse whether to parse the input as a delimited string
    # @option names [Class] :parser a parser to use for this call only
    # @return [MakeTaggable::TagList] self, so calls can be chained
    #
    # @example
    #   tag_list.add("Fun", "Happy")
    #   tag_list.add("Fun, Happy", parse: true)
    #
    def add(*names)
      extract_and_apply_options!(names)
      concat(names)
      clean!
      self
    end

    ##
    # Adds one tag to the list.
    #
    # @param obj [String, Symbol] the tag to add
    # @return [MakeTaggable::TagList] self, so appends can be chained
    #
    def <<(obj)
      add(obj)
    end

    ##
    # Joins two tag lists into a third, leaving both untouched.
    #
    # @param other [Array<String>] the tags to append
    # @return [MakeTaggable::TagList] a new list
    #
    def +(other)
      TagList.new.add(self).add(other)
    end

    ##
    # Appends another list's tags to this one.
    #
    # @param other_tag_list [Array<String>] the tags to append
    # @return [MakeTaggable::TagList] self
    #
    def concat(other_tag_list)
      super.send(:clean!)
      self
    end

    ##
    # Removes tags from the list.
    #
    # @param names [Array<String, Symbol>] the tags to remove, optionally followed by an options
    #   hash accepted by {#add}
    # @return [MakeTaggable::TagList] self
    #
    # @example
    #   tag_list.remove("Sad", "Lonely")
    #   tag_list.remove("Sad, Lonely", parse: true)
    #
    def remove(*names)
      extract_and_apply_options!(names)

      # The list holds strings, so compare strings. Everything else that takes
      # tag names normalises them -- add runs them through clean!, tagged_with
      # parses them -- and a symbol silently matching nothing here was the odd
      # one out.
      names = names.map(&:to_s)

      delete_if { |name| names.include?(name) }
      self
    end

    ##
    # Renders the list as a delimited string, suitable for a form field.
    #
    # Tags containing the delimiter are quoted, so the string parses back into the same list.
    #
    # @return [String]
    #
    # @example
    #   MakeTaggable::TagList.new("Round", "Square,Cube").to_s
    #   # => 'Round, "Square,Cube"'
    #
    def to_s
      tags = frozen? ? dup : self
      tags.send(:clean!)

      delimiter = Regexp.union(Array(MakeTaggable.delimiter))

      tags.map { |name|
        name.index(delimiter) ? "\"#{name}\"" : name
      }.join(MakeTaggable.glue)
    end

    private

    # Convert everything to string, remove whitespace, duplicates, and blanks.
    def clean!
      reject!(&:blank?)
      map!(&:to_s)
      map!(&:strip)
      map!(&:downcase) if MakeTaggable.force_lowercase
      # A name with no ASCII in it parameterizes to "", and reject! below would
      # then drop it -- so the tag vanished rather than being slugged. Keep the
      # original where there is no slug to be had; a caller who wanted strict
      # slugs still gets one wherever one exists.
      map! { |tag| tag.parameterize.presence || tag } if MakeTaggable.force_parameterize

      MakeTaggable.strict_case_match ? uniq! : uniq! { |tag| tag.downcase }
      self
    end

    def extract_and_apply_options!(args)
      options = args.last.is_a?(Hash) ? args.pop : {}
      options.assert_valid_keys :parse, :parser

      chosen_parser = options[:parser] || parser

      args.map! { |a| chosen_parser.new(a).parse } if options[:parse] || options[:parser]

      args.flatten!
    end
  end
end
