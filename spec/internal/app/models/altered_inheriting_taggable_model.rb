require_relative 'taggable_model'

class AlteredInheritingTaggableModel < TaggableModel
  make_taggable :parts
end
