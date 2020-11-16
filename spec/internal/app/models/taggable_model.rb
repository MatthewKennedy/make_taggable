class TaggableModel < ActiveRecord::Base
  acts_as_taggable
  make_taggable :languages
  make_taggable :skills
  make_taggable :needs, :offerings
  has_many :untaggable_models

  attr_reader :tag_list_submethod_called

  def tag_list=(v)
    @tag_list_submethod_called = true
    super
  end
end
