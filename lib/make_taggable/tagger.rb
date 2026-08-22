# frozen_string_literal: true

module MakeTaggable
  ##
  # Ownership of tags. Mixed into Active Record automatically, which is what puts {ClassMethods#make_tagger}
  # on every model.
  #
  module Tagger
    ##
    # @param base [Class] the class being extended
    # @return [void]
    #
    # @api private
    #
    def self.included(base)
      base.extend ClassMethods
    end

    ##
    # Added to every Active Record model.
    #
    module ClassMethods
      ##
      # Make a model a tagger, allowing its instances to claim ownership of the tags they apply.
      #
      # Adds an `owned_taggings` association and an `owned_tags` association to the model.
      #
      # @param opts [Hash] options forwarded to the generated `owned_taggings` association
      # @option opts [Proc] :scope a scope applied to the `owned_taggings` association
      # @return [void]
      #
      # @example
      #   class User < ActiveRecord::Base
      #     make_tagger
      #   end
      #
      def make_tagger(opts = {})
        class_eval do
          owned_taggings_scope = opts.delete(:scope)

          has_many :owned_taggings, owned_taggings_scope,
            **opts.merge(
              as: :tagger,
              class_name: "::MakeTaggable::Tagging",
              dependent: :destroy
            )

          has_many :owned_tags, -> { distinct },
            class_name: "::MakeTaggable::Tag",
            source: :tag,
            through: :owned_taggings
        end

        include MakeTaggable::Tagger::InstanceMethods
        extend MakeTaggable::Tagger::SingletonMethods
      end

      ##
      # Whether this model claims ownership of the tags it applies.
      #
      # @return [TrueClass, FalseClass] `false` until {#make_tagger} is called
      #
      def tagger?
        false
      end

      ##
      # @return [TrueClass, FalseClass]
      # @see #tagger?
      #
      def is_tagger?
        tagger?
      end
    end

    ##
    # Added to a model once it is a tagger.
    #
    module InstanceMethods
      ##
      # Tags a record, with this tagger as the owner of the tags.
      #
      # The taggable is saved unless `:skip_save` is given, so the tags are persisted immediately.
      #
      # @param taggable [ActiveRecord::Base] the record to tag
      # @param opts [Hash] the tagging options
      # @option opts [String, Array<String>] :with the tags to apply
      # @option opts [Symbol, String] :on the context to apply them in
      # @option opts [TrueClass, FalseClass] :skip_save whether to leave the taggable unsaved
      # @option opts [TrueClass, FalseClass] :force whether to allow a context the model does not
      #   declare, on by default
      # @return [TrueClass, FalseClass] whether the taggable saved, or `false` when it is not taggable
      # @raise [RuntimeError] when `:on` or `:with` is missing, or the context is undeclared and
      #   `:force` is off
      #
      # @example
      #   @user.tag(@photo, with: "paris, normandy", on: :locations)
      #
      def tag(taggable, opts = {})
        opts.reverse_merge!(force: true)
        skip_save = opts.delete(:skip_save)
        return false unless taggable.respond_to?(:is_taggable?) && taggable.is_taggable?

        fail "You need to specify a tag context using :on" unless opts.key?(:on)
        fail "You need to specify some tags using :with" unless opts.key?(:with)
        fail "No context :#{opts[:on]} defined in #{taggable.class}" unless opts[:force] || taggable.tag_types.include?(opts[:on])

        taggable.set_owner_tag_list_on(self, opts[:on].to_s, opts[:with])
        taggable.save unless skip_save
      end

      ##
      # Whether this record claims ownership of the tags it applies.
      #
      # @return [TrueClass, FalseClass]
      #
      def tagger?
        self.class.is_tagger?
      end

      ##
      # @return [TrueClass, FalseClass]
      # @see #tagger?
      #
      def is_tagger?
        tagger?
      end
    end

    ##
    # Replaces {ClassMethods#tagger?} once a model is a tagger.
    #
    module SingletonMethods
      ##
      # @return [TrueClass, FalseClass] always `true`
      #
      def tagger?
        true
      end

      ##
      # @return [TrueClass, FalseClass]
      # @see #tagger?
      #
      def is_tagger?
        tagger?
      end
    end
  end
end
