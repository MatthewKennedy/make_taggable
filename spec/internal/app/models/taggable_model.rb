class TaggableModel < ActiveRecord::Base
  acts_as_taggable
  uggle :languages
  uggle :skills
  uggle :needs, :offerings
  has_many :untaggable_models

  attr_reader :tag_list_submethod_called

  def tag_list=(v)
    @tag_list_submethod_called = true
    super
  end
end
