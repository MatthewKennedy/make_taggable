module MakeTaggable
  class Configuration
    attr_accessor :force_lowercase, :force_parameterize,
      :remove_unused_tags, :default_parser,
      :tags_counter, :tags_table,
      :taggings_table
    attr_reader :delimiter, :strict_case_match

    def initialize
      @delimiter = ","
      @force_lowercase = false
      @force_parameterize = false
      @strict_case_match = false
      @remove_unused_tags = false
      @tags_counter = true
      @default_parser = DefaultParser
      @tags_table = :tags
      @taggings_table = :taggings
    end

    attr_writer :strict_case_match

    def delimiter=(string)
      ActiveRecord::Base.logger.warn <<~WARNING
        MakeTaggable.delimiter is deprecated \
        and will be removed from v4.0+, use  \
        a MakeTaggable.default_parser instead
      WARNING
      @delimiter = string
    end
  end
end
