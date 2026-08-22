# Models standing in for a host application's own Active Record classes.

class TaggableModel < ActiveRecord::Base
  make_taggable
  make_taggable :languages
  make_taggable :skills
  make_taggable :needs, :offerings
  has_many :untaggable_models

  attr_reader :tag_list_submethod_called

  def tag_list=(value)
    @tag_list_submethod_called = true
    super
  end
end

class InheritingTaggableModel < TaggableModel
end

class AlteredInheritingTaggableModel < TaggableModel
  make_taggable :parts
end

class ColumnsOverrideModel < ActiveRecord::Base
  def self.columns
    super.reject { |c| c.name == "ignored_column" }
  end
end

class NonStandardIdTaggableModel < ActiveRecord::Base
  self.primary_key = :an_id
  make_taggable
  make_taggable :languages
  make_taggable :skills
  make_taggable :needs, :offerings
  has_many :untaggable_models
end

class UntaggableModel < ActiveRecord::Base
  belongs_to :taggable_model
end

class CachedModel < ActiveRecord::Base
  make_taggable
end

class OtherCachedModel < ActiveRecord::Base
  make_taggable :languages, :statuses, :glasses
end

class CacheMethodsInjectedModel < ActiveRecord::Base
  make_taggable
end

class OtherTaggableModel < ActiveRecord::Base
  make_taggable :tags, :languages
  make_taggable :needs, :offerings
end

class OrderedTaggableModel < ActiveRecord::Base
  make_ordered_taggable
  make_ordered_taggable :colours
end

class Market < MakeTaggable::Tag
end

class Company < ActiveRecord::Base
  make_taggable :locations, :markets

  has_many :markets, through: :market_taggings, source: :tag

  private

  def find_or_create_tags_from_list_with_context(tag_list, context)
    if context.to_sym == :markets
      Market.find_or_create_all_with_like_by_name(tag_list)
    else
      super
    end
  end
end

class User < ActiveRecord::Base
  make_tagger
end

class Student < User
end

if MakeTaggable::Utils.using_postgresql?
  class CachedModelWithArray < ActiveRecord::Base
    self.table_name = "other_cached_with_array_models"
    make_taggable
  end

  class TaggableModelWithJson < ActiveRecord::Base
    self.table_name = "taggable_model_with_jsons"
    make_taggable
    make_taggable :skills
  end
end

# A Rails host application eager-loads its models, which resolves each class's
# columns and gives MakeTaggable::Taggable::Cache the chance to inject its
# caching methods. Nothing forces that in a bare Active Record process, so the
# suite does it explicitly.
#
# CacheMethodsInjectedModel is deliberately left out: one example asserts that
# the injection still happens lazily, on first use.
[CachedModel, OtherCachedModel, TaggableModel].each(&:columns)
