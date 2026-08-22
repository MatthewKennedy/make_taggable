# frozen_string_literal: true

module MakeTaggable::Taggable
  ##
  # The Active Model type backing each generated `*_list` attribute, so tag lists take part in
  # dirty tracking alongside ordinary columns.
  #
  # @api private
  #
  class TagListType < ActiveModel::Type::Value
  end
end
