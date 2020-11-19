class NonStandardIdTaggableModel < ActiveRecord::Base
  self.primary_key = :an_id
  acts_as_taggable
  make_taggable :languages
  make_taggable :skills
  make_taggable :needs, :offerings
  has_many :untaggable_models
end
