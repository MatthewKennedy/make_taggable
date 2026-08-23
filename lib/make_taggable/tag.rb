# frozen_string_literal: true

module MakeTaggable
  ##
  # A tag name, shared by every record tagged with it.
  #
  # Tags are found and created through the class methods here rather than directly, so that the
  # configured case sensitivity is applied consistently. Subclass it to keep a separate vocabulary
  # for one context, and point at the subclass from
  # {MakeTaggable::Taggable::Core#find_or_create_tags_from_list_with_context}.
  #
  # @!attribute [rw] name
  #   The tag itself.
  #   @return [String]
  # @!attribute [rw] taggings_count
  #   How many taggings reference this tag, maintained as a counter cache.
  #   @return [Integer]
  #
  class Tag < ::ActiveRecord::Base
    self.table_name = MakeTaggable.tags_table

    ### ASSOCIATIONS:
    has_many :taggings, dependent: :destroy, class_name: "::MakeTaggable::Tagging"

    ### VALIDATIONS:
    validates_presence_of :name
    # Two declarations, one of which runs. A tags table with a `type` column is
    # being used for single table inheritance -- a Tag subclass per vocabulary --
    # and there a name is expected to repeat across subclasses: "energy" as a
    # Market and as a Genre. Scoping the check keeps it meaningful within a
    # subclass rather than making the whole thing something to switch off.
    #
    # The column is looked up per validation rather than when this class loads,
    # because the class can load before the migration that adds it has run.
    validates_uniqueness_of :name,
      if: -> { validates_name_uniqueness? && !self.class.tag_type_column? },
      case_sensitive: true

    validates_uniqueness_of :name,
      scope: :type,
      if: -> { validates_name_uniqueness? && self.class.tag_type_column? },
      case_sensitive: true
    validates_length_of :name, maximum: 255

    ##
    # Whether the uniqueness validation on `name` runs.
    #
    # Override this in a subclass to allow tag names to repeat.
    #
    # @return [TrueClass, FalseClass] always `true` here
    #
    def validates_name_uniqueness?
      true
    end

    ##
    # Whether the tags table carries a `type` column, and so is being used for single table
    # inheritance.
    #
    # @return [TrueClass, FalseClass]
    #
    # @api private
    #
    def self.tag_type_column?
      column_names.include?("type")
    end

    ### SCOPES:
    scope :most_used, ->(limit = 20) { order("taggings_count desc").limit(limit) }
    scope :least_used, ->(limit = 20) { order("taggings_count asc").limit(limit) }

    ##
    # Tags matching a name exactly, honouring the configured case sensitivity.
    #
    # @param name [String] the name to match
    # @return [ActiveRecord::Relation]
    #
    def self.named(name)
      if MakeTaggable.strict_case_match
        where(["name = #{binary}?", name.to_s])
      else
        where(["LOWER(name) = LOWER(?)", name.to_s.downcase])
      end
    end

    ##
    # Tags matching any of the given names exactly.
    #
    # @param list [Array<String>] the names to match
    # @return [ActiveRecord::Relation]
    #
    def self.named_any(list)
      clause = list.map { |tag|
        sanitize_sql_for_named_any(tag)
      }.join(" OR ")
      where(clause)
    end

    ##
    # Tags whose name contains the given fragment.
    #
    # Case insensitive on PostgreSQL, which uses `ILIKE`; otherwise it follows the column's
    # collation.
    #
    # @param name [String] the fragment to look for
    # @return [ActiveRecord::Relation]
    #
    def self.named_like(name)
      clause = ["name #{MakeTaggable::Utils.like_operator} ? ESCAPE '!'", "%#{MakeTaggable::Utils.escape_like(name)}%"]
      where(clause)
    end

    ##
    # Tags whose name contains any of the given fragments.
    #
    # @param list [Array<String>] the fragments to look for
    # @return [ActiveRecord::Relation]
    #
    def self.named_like_any(list)
      clause = list.map { |tag|
        sanitize_sql(["name #{MakeTaggable::Utils.like_operator} ? ESCAPE '!'", "%#{MakeTaggable::Utils.escape_like(tag.to_s)}%"])
      }.join(" OR ")
      where(clause)
    end

    ##
    # Tags used in a given context, whatever the record they were applied to.
    #
    # @param context [String, Symbol] the tagging context
    # @return [ActiveRecord::Relation]
    #
    # @example
    #   MakeTaggable::Tag.for_context(:skills)
    #
    def self.for_context(context)
      joins(:taggings)
        .where(["#{MakeTaggable.taggings_table}.context = ?", context])
        .select("DISTINCT #{MakeTaggable.tags_table}.*")
    end

    ### CLASS METHODS:

    ##
    # Finds a tag by name, creating it when it does not exist yet.
    #
    # The name is matched in full. Honours the configured case sensitivity.
    #
    # @param name [String] the tag name
    # @return [MakeTaggable::Tag]
    #
    # @example
    #   MakeTaggable::Tag.find_or_create_with_like_by_name("ruby")
    #
    def self.find_or_create_with_like_by_name(name)
      if MakeTaggable.strict_case_match
        find_or_create_all_with_like_by_name([name]).first
      else
        # Matching has to happen in Ruby's terms rather than the column's: the
        # MySQL migration collates tag names as utf8mb4_bin, which would make a
        # LIKE comparison case sensitive whatever strict_case_match says.
        named(name).first || create(name: name)
      end
    end

    ##
    # Finds every tag in a list by name, creating those that do not exist yet.
    #
    # A competing write that takes a name first is retried up to three times before giving up.
    # Each insert runs in a savepoint of its own, so a name lost to a race unwinds that insert
    # alone -- an enclosing transaction the caller opened is left untouched, along with everything
    # written into it.
    #
    # @param list [Array<String>] the tag names
    # @return [Array<MakeTaggable::Tag>] in the order the names were given
    # @raise [MakeTaggable::DuplicateTagError] when a name stays taken after three attempts
    #
    # @example
    #   MakeTaggable::Tag.find_or_create_all_with_like_by_name(%w[ruby rails])
    #
    def self.find_or_create_all_with_like_by_name(*list)
      list = Array(list).flatten

      return [] if list.empty?

      existing_tags = named_any(list).to_a
      list.map do |tag_name|
        tries ||= 3
        comparable_tag_name = comparable_name(tag_name)
        existing_tag = existing_tags.find { |tag| comparable_name(tag.name) == comparable_tag_name }
        next existing_tag if existing_tag

        # Tags created earlier in this call have to stay visible to the names
        # that follow, or a list holding both "Ruby" and "ruby" resolves to two
        # rows even though the two names compare equal.
        #
        # The insert gets a savepoint of its own so that a RecordNotUnique
        # unwinds only the failed insert. Without one the caller's transaction
        # is left in an aborted state and everything it had done is lost.
        transaction(requires_new: true) { create(name: tag_name) }.tap { |tag| existing_tags << tag }
        # A deadlock counts as losing the race, the same as a duplicate key.
        # MySQL reports one or the other depending on how two inserts of the
        # same name interleave on the unique index, and both mean the work
        # should be re-read and retried rather than abandoned.
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::Deadlocked
        if (tries -= 1).positive?
          existing_tags = named_any(list).to_a
          retry
        end

        raise DuplicateTagError.new("'#{tag_name}' has already been taken")
      end
    end

    ### INSTANCE METHODS:

    ##
    # Compares tags by name, so a saved tag and an unsaved one with the same name are equal.
    #
    # @param other [Object] the object to compare against
    # @return [TrueClass, FalseClass]
    #
    def ==(other)
      super || (other.is_a?(Tag) && name == other.name)
    end

    ##
    # The tag's name, so a tag renders as itself in a view or a string.
    #
    # @return [String]
    #
    def to_s
      name
    end

    ##
    # How many times this tag matched, on relations that select a count alongside the tag columns.
    #
    # Zero on a tag loaded without one.
    #
    # @return [Integer]
    #
    def count
      read_attribute(:count).to_i
    end

    class << self
      private

      def comparable_name(str)
        if MakeTaggable.strict_case_match
          str
        else
          str.to_s.downcase
        end
      end

      def binary
        MakeTaggable::Utils.using_mysql? ? "BINARY " : nil
      end

      def sanitize_sql_for_named_any(tag)
        if MakeTaggable.strict_case_match
          sanitize_sql(["name = #{binary}?", tag.to_s])
        else
          sanitize_sql(["LOWER(name) = LOWER(?)", tag.to_s.downcase])
        end
      end
    end
  end
end
