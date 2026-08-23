# frozen_string_literal: true

module MakeTaggable::Taggable
  ##
  # Finding records that share tags with this one.
  #
  # Results come back ordered by how many tags matched, most first, and carry that figure as a
  # `count` attribute.
  #
  module Related
    ##
    # @param base [Class] the model being made taggable
    # @return [void]
    #
    # @api private
    #
    def self.included(base)
      base.extend MakeTaggable::Taggable::Related::ClassMethods
      base.initialize_make_taggable_related
    end

    ##
    # Added to every taggable model.
    #
    module ClassMethods
      ##
      # Defines `find_related_<context>` and `find_related_<context>_for` for each context.
      #
      # @return [void]
      #
      def initialize_make_taggable_related
        tag_types.map(&:to_s).each do |tag_type|
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def find_related_#{tag_type}(options = {})
              related_tags_for('#{tag_type}', self.class, options)
            end
            alias_method :find_related_on_#{tag_type}, :find_related_#{tag_type}

            def find_related_#{tag_type}_for(klass, options = {})
              related_tags_for('#{tag_type}', klass, options)
            end
          RUBY
        end
      end

      ##
      # Adds contexts and refreshes the related-record finders.
      #
      # @param args [Array<Symbol, String>] the contexts to add
      # @return [void]
      #
      def make_taggable(*args)
        super
        initialize_make_taggable_related
      end
    end

    ##
    # Records of this model tagged, in one context, with the tags this record carries in another.
    #
    # @param search_context [Symbol, String] the context to take this record's tags from
    # @param result_context [Symbol, String] the context to match them against
    # @param options [Hash] reserved for future use
    # @return [ActiveRecord::Relation] ordered by number of matching tags, descending
    #
    def find_matching_contexts(search_context, result_context, options = {})
      matching_contexts_for(search_context.to_s, result_context.to_s, self.class, options)
    end

    ##
    # As {#find_matching_contexts}, against another model.
    #
    # @param klass [Class] the model to search
    # @param search_context [Symbol, String] the context to take this record's tags from
    # @param result_context [Symbol, String] the context to match them against
    # @param options [Hash] reserved for future use
    # @return [ActiveRecord::Relation] ordered by number of matching tags, descending
    #
    def find_matching_contexts_for(klass, search_context, result_context, options = {})
      matching_contexts_for(search_context.to_s, result_context.to_s, klass, options)
    end

    ##
    # Builds the relation behind {#find_matching_contexts}.
    #
    # @param search_context [Symbol, String] the context to take this record's tags from
    # @param result_context [Symbol, String] the context to match them against
    # @param klass [Class] the model to search
    # @param options [Hash] reserved for future use
    # @return [ActiveRecord::Relation]
    #
    def matching_contexts_for(search_context, result_context, klass, options = {})
      tags_to_find = tags_on(search_context).map { |t| t.name }
      related_where(klass, ["#{exclude_self(klass, id)} #{klass.table_name}.#{klass.primary_key} = #{MakeTaggable::Tagging.table_name}.taggable_id AND #{MakeTaggable::Tagging.table_name}.taggable_type = ? AND #{MakeTaggable::Tagging.table_name}.tag_id = #{MakeTaggable::Tag.table_name}.#{MakeTaggable::Tag.primary_key} AND #{MakeTaggable::Tag.table_name}.name IN (?) AND #{MakeTaggable::Tagging.table_name}.context = ?", klass.base_class.to_s, tags_to_find, result_context])
    end

    ##
    # Builds the relation behind each generated `find_related_<context>` method.
    #
    # @param context [Symbol, String] the context to match on
    # @param klass [Class] the model to search
    # @param options [Hash] the search options
    # @option options [String, Array<String>] :ignore tags to leave out of the match
    # @return [ActiveRecord::Relation] ordered by number of matching tags, descending
    #
    def related_tags_for(context, klass, options = {})
      tags_to_ignore = Array.wrap(options[:ignore]).map(&:to_s) || []
      tags_to_find = tags_on(context).map { |t| t.name }.reject { |t| tags_to_ignore.include? t }
      related_where(klass, ["#{exclude_self(klass, id)} #{klass.table_name}.#{klass.primary_key} = #{MakeTaggable::Tagging.table_name}.taggable_id AND #{MakeTaggable::Tagging.table_name}.taggable_type = ? AND #{MakeTaggable::Tagging.table_name}.tag_id = #{MakeTaggable::Tag.table_name}.#{MakeTaggable::Tag.primary_key} AND #{MakeTaggable::Tag.table_name}.name IN (?) AND #{MakeTaggable::Tagging.table_name}.context = ?", klass.base_class.to_s, tags_to_find, context])
    end

    private

    def exclude_self(klass, id)
      "#{klass.arel_table[klass.primary_key].not_eq(id).to_sql} AND" if [self.class.base_class, self.class].include? klass
    end

    # Grouping by the primary key alone is enough on every adapter we support.
    #
    # PostgreSQL used to need every selected non-aggregated column listed here,
    # which is why this branched. Since 9.1 it works the functional dependency
    # out from the primary key on its own, and listing every column actively
    # breaks a model with a `json` column -- json has no equality operator, so
    # it cannot appear in a GROUP BY at all.
    def group_columns(klass)
      "#{klass.table_name}.#{klass.primary_key}"
    end

    def related_where(klass, conditions)
      klass.select("#{klass.table_name}.*, COUNT(#{MakeTaggable::Tag.table_name}.#{MakeTaggable::Tag.primary_key}) AS count")
        .from("#{klass.table_name}, #{MakeTaggable::Tag.table_name}, #{MakeTaggable::Tagging.table_name}")
        .group(group_columns(klass))
        .order("count DESC")
        .where(conditions)
        .extending(CalculationMethods)
    end

    # These relations select the taggable's columns plus an aliased count, and
    # order by that alias. Active Record folds the select list into the COUNT()
    # it builds, which produced SQL no adapter accepts:
    #
    #   SELECT COUNT(taggable_models.*, COUNT(tags.id) AS count) ...
    #
    # Counting rows instead is not enough on its own either: the relation groups
    # by primary key over a cross join, so dropping the grouping counts taggings
    # rather than records, and the ORDER BY still names an alias that a bare
    # COUNT(*) no longer selects.
    #
    # So count the grouped query as a subquery. `klass.unscoped` is the shell
    # for it because it carries no extension of its own -- counting a relation
    # derived from this one would re-enter this method.
    module CalculationMethods
      ##
      # The number of related records.
      #
      # @param column_name [Symbol, String] accepted for signature compatibility; ignored
      # @return [Integer]
      #
      def count(column_name = :all)
        ids = except(:select, :order).select(Arel.sql("#{klass.table_name}.#{klass.primary_key}"))

        klass.unscoped.from(Arel.sql("(#{ids.to_sql}) AS #{klass.table_name}_related")).count(:all)
      end

      ##
      # @return [Integer] the number of related records
      #
      def size
        loaded? ? to_a.size : count
      end
    end
  end
end
