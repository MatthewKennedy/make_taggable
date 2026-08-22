# frozen_string_literal: true

module MakeTaggable
  ##
  # Declaring a model taggable. Mixed into Active Record automatically, which is what puts
  # {#make_taggable} on every model.
  #
  module Taggable
    ##
    # Whether this model has been made taggable.
    #
    # @return [TrueClass, FalseClass] `false` until {#make_taggable} is called
    #
    def taggable?
      false
    end

    ##
    # Make a model taggable on the given contexts.
    #
    # Called without arguments it makes the model taggable on `:tags`, which is the context every
    # other part of the library treats as the default.
    #
    # @param tag_types [Array<Symbol, String>] the contexts to tag on
    # @return [void]
    #
    # @example A single, default context
    #   class Book < ActiveRecord::Base
    #     make_taggable
    #   end
    #
    # @example Several named contexts
    #   class User < ActiveRecord::Base
    #     make_taggable :languages, :skills
    #   end
    #
    def make_taggable(*tag_types)
      tag_types = [:tags] if tag_types.flatten.compact.empty?

      taggable_on(false, tag_types)
    end

    ##
    # Make a model taggable on the given contexts, preserving the order in which tags were added.
    #
    # Called without arguments it makes the model taggable on `:tags`.
    #
    # @param tag_types [Array<Symbol, String>] the contexts to tag on
    # @return [void]
    #
    # @example
    #   class User < ActiveRecord::Base
    #     make_ordered_taggable :languages, :skills
    #   end
    #
    def make_ordered_taggable(*tag_types)
      tag_types = [:tags] if tag_types.flatten.compact.empty?

      taggable_on(true, tag_types)
    end

    private

    # Make a model taggable on specified contexts
    # and optionally preserves the order in which tags are created
    #
    # NB: method overridden in core module in order to create tag type
    #     associations and methods after this logic has executed
    #
    def taggable_on(preserve_tag_order, *tag_types)
      tag_types = tag_types.to_a.flatten.compact.map(&:to_sym)

      if taggable?
        self.tag_types = (self.tag_types + tag_types).uniq
        self.preserve_tag_order = preserve_tag_order
      else
        class_attribute :tag_types
        self.tag_types = tag_types
        class_attribute :preserve_tag_order
        self.preserve_tag_order = preserve_tag_order

        class_eval do
          has_many :taggings, as: :taggable, dependent: :destroy, class_name: "::MakeTaggable::Tagging"
          has_many :base_tags, through: :taggings, source: :tag, class_name: "::MakeTaggable::Tag"

          def self.taggable?
            true
          end
        end
      end

      # each of these add context-specific methods and must be
      # called on each call of taggable_on
      include Core
      include Collection
      include Cache
      include Ownership
      include Related
    end
  end
end
