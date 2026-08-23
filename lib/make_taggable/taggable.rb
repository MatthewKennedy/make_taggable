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
      tag_types.each { |tag_type| validate_tag_context!(tag_type) }

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
          has_many :base_tags, through: :taggings, source: :tag, class_name: MakeTaggable.tag_class

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

    # Rejects a context that cannot become the methods and instance variables the
    # library generates from it.
    #
    # A context is interpolated straight into generated source -- `#{context}_list`,
    # `#{context}_taggings`, `@#{context}_list`. A name that is not a valid identifier
    # produces source Ruby cannot parse, and the resulting SyntaxError descends from
    # ScriptError rather than StandardError, so it slips past an application's own
    # rescue and takes the boot down pointing at Active Record's association builder
    # rather than at the offending declaration.
    #
    # Validity is decided by asking Ruby rather than by pattern, so a context is
    # accepted on exactly the terms the generated code needs -- non-ASCII names
    # included, since those make perfectly good method names.
    #
    # @param tag_type [Symbol] the context being declared
    # @return [void]
    # @raise [ArgumentError] when the context cannot become an identifier
    def validate_tag_context!(tag_type)
      Object.new.instance_variable_defined?(:"@#{tag_type}_list")
    rescue NameError
      raise ArgumentError,
        "#{tag_type.inspect} cannot be used as a tag context: " \
        "make_taggable generates methods and instance variables from it, and " \
        "\"#{tag_type}_list\" is not a valid Ruby name."
    end
  end
end
