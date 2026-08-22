# frozen_string_literal: true

module MakeTaggable::Taggable
  ##
  # Counting tags, for tag clouds and "most used" lists.
  #
  # Each context gets `<context>_counts` and `top_<context>` on both the class and its instances.
  #
  module Collection
    ##
    # @param base [Class] the model being made taggable
    # @return [void]
    #
    # @api private
    #
    def self.included(base)
      base.extend MakeTaggable::Taggable::Collection::ClassMethods
      base.initialize_make_taggable_collection
    end

    ##
    # Added to every taggable model.
    #
    module ClassMethods
      ##
      # Defines the counting methods for each context.
      #
      # @return [void]
      #
      def initialize_make_taggable_collection
        tag_types.map(&:to_s).each do |tag_type|
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def self.#{tag_type.singularize}_counts(options={})
              tag_counts_on('#{tag_type}', options)
            end

            def #{tag_type.singularize}_counts(options = {})
              tag_counts_on('#{tag_type}', options)
            end

            def top_#{tag_type}(limit = 10)
              tag_counts_on('#{tag_type}', order: 'count desc', limit: limit.to_i)
            end

            def self.top_#{tag_type}(limit = 10)
              tag_counts_on('#{tag_type}', order: 'count desc', limit: limit.to_i)
            end
          RUBY
        end
      end

      ##
      # Adds contexts and refreshes the counting methods.
      #
      # @param args [Array<Symbol, String>] the contexts to add
      # @return [void]
      #
      def make_taggable(*args)
        super
        initialize_make_taggable_collection
      end

      ##
      # Tags used in one context, each carrying how often it was used.
      #
      # @param context [Symbol, String] the tagging context
      # @param options [Hash] options accepted by {#all_tag_counts}
      # @return [ActiveRecord::Relation]
      #
      # @example
      #   Book.tag_counts_on(:genres)
      #
      def tag_counts_on(context, options = {})
        all_tag_counts(options.merge({on: context.to_s}))
      end

      ##
      # Tags used in one context, without counting them.
      #
      # @param context [Symbol, String] the tagging context
      # @param options [Hash] options accepted by {#all_tags}
      # @return [ActiveRecord::Relation]
      #
      def tags_on(context, options = {})
        all_tags(options.merge({on: context.to_s}))
      end

      ##
      # Every tag applied to this model, without counting them.
      #
      # Cheaper than {#all_tag_counts}, which has to join the taggables.
      #
      # @param options [Hash] the query options
      # @option options [Time, Date] :start_at only tags applied after this time
      # @option options [Time, Date] :end_at only tags applied before this time
      # @option options [String, Array] :conditions SQL conditions added to the tag query
      # @option options [Integer] :limit the most tags to return
      # @option options [String] :order SQL to order by, such as `"tags.name asc"`
      # @option options [Symbol, String] :on only tags applied in this context
      # @return [ActiveRecord::Relation]
      #
      def all_tags(options = {})
        options = options.dup
        options.assert_valid_keys :start_at, :end_at, :conditions, :order, :limit, :on

        ## Generate conditions:
        options[:conditions] = sanitize_sql(options[:conditions]) if options[:conditions]

        ## Generate scope:
        tagging_scope = MakeTaggable::Tagging.select("#{MakeTaggable::Tagging.table_name}.tag_id")
        tag_scope = MakeTaggable::Tag.select("#{MakeTaggable::Tag.table_name}.*").order(options[:order]).limit(options[:limit])

        # Joins and conditions
        tagging_conditions(options).each { |condition| tagging_scope = tagging_scope.where(condition) }
        tag_scope = tag_scope.where(options[:conditions])

        group_columns = "#{MakeTaggable::Tagging.table_name}.tag_id"

        # Append the current scope to the scope, because we can't use scope(:find) in RoR 3.0 anymore:
        tagging_scope = generate_tagging_scope_in_clause(tagging_scope, table_name, primary_key).group(group_columns)

        tag_scope_joins(tag_scope, tagging_scope)
      end

      ##
      # Every tag applied to this model, each carrying how often it was used as a `count` attribute.
      #
      # @param options [Hash] the query options
      # @option options [Time, Date] :start_at only tags applied after this time
      # @option options [Time, Date] :end_at only tags applied before this time
      # @option options [String, Array] :conditions SQL conditions added to the tag query
      # @option options [Integer] :limit the most tags to return
      # @option options [String] :order SQL to order by, such as `"count desc"`
      # @option options [Integer] :at_least skip tags used fewer times than this
      # @option options [Integer] :at_most skip tags used more times than this
      # @option options [Symbol, String] :on only tags applied in this context
      # @return [ActiveRecord::Relation]
      #
      # @example The ten most used genres
      #   Book.all_tag_counts(on: :genres, order: "count desc", limit: 10)
      #
      def all_tag_counts(options = {})
        options = options.dup
        options.assert_valid_keys :start_at, :end_at, :conditions, :at_least, :at_most, :order, :limit, :on, :id

        ## Generate conditions:
        options[:conditions] = sanitize_sql(options[:conditions]) if options[:conditions]

        ## Generate scope:
        tagging_scope = MakeTaggable::Tagging.select("#{MakeTaggable::Tagging.table_name}.tag_id, COUNT(#{MakeTaggable::Tagging.table_name}.tag_id) AS tags_count")
        tag_scope = MakeTaggable::Tag.select("#{MakeTaggable::Tag.table_name}.*, #{MakeTaggable::Tagging.table_name}.tags_count AS count").order(options[:order]).limit(options[:limit])

        # Current model is STI descendant, so add type checking to the join condition
        unless descends_from_active_record?
          taggable_join = "INNER JOIN #{table_name} ON #{table_name}.#{primary_key} = #{MakeTaggable::Tagging.table_name}.taggable_id"
          taggable_join += sanitize_sql([" AND #{table_name}.#{inheritance_column} = ?", name])
          tagging_scope = tagging_scope.joins(taggable_join)
        end

        # Conditions
        tagging_conditions(options).each { |condition| tagging_scope = tagging_scope.where(condition) }
        tag_scope = tag_scope.where(options[:conditions])

        # GROUP BY and HAVING clauses:
        having = ["COUNT(#{MakeTaggable::Tagging.table_name}.tag_id) > 0"]
        having.push sanitize_sql(["COUNT(#{MakeTaggable::Tagging.table_name}.tag_id) >= ?", options.delete(:at_least)]) if options[:at_least]
        having.push sanitize_sql(["COUNT(#{MakeTaggable::Tagging.table_name}.tag_id) <= ?", options.delete(:at_most)]) if options[:at_most]
        having = having.compact.join(" AND ")

        group_columns = "#{MakeTaggable::Tagging.table_name}.tag_id"

        unless options[:id]
          # Append the current scope to the scope, because we can't use scope(:find) in RoR 3.0 anymore:
          tagging_scope = generate_tagging_scope_in_clause(tagging_scope, table_name, primary_key)
        end

        tagging_scope = tagging_scope.group(group_columns).having(having)

        tag_scope_joins(tag_scope, tagging_scope)
      end

      ##
      # A relation's SQL with its bind parameters inlined, so it can be embedded in another query.
      #
      # @param relation [ActiveRecord::Relation] the relation to render
      # @return [String]
      #
      # @api private
      #
      def safe_to_sql(relation)
        connection.unprepared_statement { relation.to_sql }
      end

      private

      def generate_tagging_scope_in_clause(tagging_scope, table_name, primary_key)
        table_name_pkey = "#{table_name}.#{primary_key}"
        if MakeTaggable::Utils.using_mysql?
          # See https://github.com/mbleigh/acts-as-taggable-on/pull/457 for details
          scoped_ids = pluck(table_name_pkey)
          tagging_scope = tagging_scope.where("#{MakeTaggable::Tagging.table_name}.taggable_id IN (?)", scoped_ids)
        else
          tagging_scope = tagging_scope.where("#{MakeTaggable::Tagging.table_name}.taggable_id IN(#{safe_to_sql(except(:select).select(table_name_pkey))})")
        end

        tagging_scope
      end

      def tagging_conditions(options)
        tagging_conditions = []
        tagging_conditions.push sanitize_sql(["#{MakeTaggable::Tagging.table_name}.created_at <= ?", options.delete(:end_at)]) if options[:end_at]
        tagging_conditions.push sanitize_sql(["#{MakeTaggable::Tagging.table_name}.created_at >= ?", options.delete(:start_at)]) if options[:start_at]

        taggable_conditions = sanitize_sql(["#{MakeTaggable::Tagging.table_name}.taggable_type = ?", base_class.name])
        taggable_conditions << sanitize_sql([" AND #{MakeTaggable::Tagging.table_name}.context = ?", options.delete(:on).to_s]) if options[:on]
        taggable_conditions << sanitize_sql([" AND #{MakeTaggable::Tagging.table_name}.taggable_id = ?", options[:id]]) if options[:id]

        tagging_conditions.push taggable_conditions

        tagging_conditions
      end

      def tag_scope_joins(tag_scope, tagging_scope)
        tag_scope = tag_scope.joins("JOIN (#{safe_to_sql(tagging_scope)}) AS #{MakeTaggable::Tagging.table_name} ON #{MakeTaggable::Tagging.table_name}.tag_id = #{MakeTaggable::Tag.table_name}.id")
        tag_scope.extending(CalculationMethods)
      end
    end

    ##
    # Tags used on this record in one context, each carrying how often it was used.
    #
    # @param context [Symbol, String] the tagging context
    # @param options [Hash] options accepted by {ClassMethods#all_tag_counts}
    # @return [ActiveRecord::Relation]
    #
    def tag_counts_on(context, options = {})
      self.class.tag_counts_on(context, options.merge(id: id))
    end

    # These relations carry a custom SELECT -- the tag columns plus an aliased
    # count -- which Active Record would otherwise fold into the COUNT(). Count
    # rows instead, whatever the relation selects.
    module CalculationMethods
      ##
      # Counts rows rather than the relation's selected columns.
      #
      # @param column_name [Symbol, String] the column to count
      # @return [Integer]
      #
      def count(column_name = :all)
        super
      end
    end
  end
end
