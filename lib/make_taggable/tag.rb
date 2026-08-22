# frozen_string_literal: true

module MakeTaggable
  class Tag < ::ActiveRecord::Base
    self.table_name = MakeTaggable.tags_table

    ### ASSOCIATIONS:
    has_many :taggings, dependent: :destroy, class_name: "::MakeTaggable::Tagging"

    ### VALIDATIONS:
    validates_presence_of :name
    validates_uniqueness_of :name, if: :validates_name_uniqueness?, case_sensitive: true
    validates_length_of :name, maximum: 255

    # Monkey patch this method if don't need name uniqueness validation
    def validates_name_uniqueness?
      true
    end

    ### SCOPES:
    scope :most_used, ->(limit = 20) { order("taggings_count desc").limit(limit) }
    scope :least_used, ->(limit = 20) { order("taggings_count asc").limit(limit) }

    def self.named(name)
      if MakeTaggable.strict_case_match
        where(["name = #{binary}?", name.to_s])
      else
        where(["LOWER(name) = LOWER(?)", name.to_s.downcase])
      end
    end

    def self.named_any(list)
      clause = list.map { |tag|
        sanitize_sql_for_named_any(tag)
      }.join(" OR ")
      where(clause)
    end

    def self.named_like(name)
      clause = ["name #{MakeTaggable::Utils.like_operator} ? ESCAPE '!'", "%#{MakeTaggable::Utils.escape_like(name)}%"]
      where(clause)
    end

    def self.named_like_any(list)
      clause = list.map { |tag|
        sanitize_sql(["name #{MakeTaggable::Utils.like_operator} ? ESCAPE '!'", "%#{MakeTaggable::Utils.escape_like(tag.to_s)}%"])
      }.join(" OR ")
      where(clause)
    end

    def self.for_context(context)
      joins(:taggings)
        .where(["#{MakeTaggable.taggings_table}.context = ?", context])
        .select("DISTINCT #{MakeTaggable.tags_table}.*")
    end

    ### CLASS METHODS:
    def self.find_or_create_with_like_by_name(name)
      if MakeTaggable.strict_case_match
        find_or_create_all_with_like_by_name([name]).first
      else
        named_like(name).first || create(name: name)
      end
    end

    def self.find_or_create_all_with_like_by_name(*list)
      list = Array(list).flatten

      return [] if list.empty?

      existing_tags = named_any(list)
      list.map do |tag_name|
        tries ||= 3
        comparable_tag_name = comparable_name(tag_name)
        existing_tag = existing_tags.find { |tag| comparable_name(tag.name) == comparable_tag_name }
        existing_tag || create(name: tag_name)
      rescue ActiveRecord::RecordNotUnique
        if (tries -= 1).positive?
          ActiveRecord::Base.connection.execute "ROLLBACK"
          existing_tags = named_any(list)
          retry
        end

        raise DuplicateTagError.new("'#{tag_name}' has already been taken")
      end
    end

    ### INSTANCE METHODS:
    def ==(other)
      super || (other.is_a?(Tag) && name == other.name)
    end

    def to_s
      name
    end

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
