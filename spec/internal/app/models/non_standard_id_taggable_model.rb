class NonStandardIdTaggableModel < ActiveRecord::Base
  self.primary_key = :an_id
  acts_as_taggable
  uggle :languages
  uggle :skills
  uggle :needs, :offerings
  has_many :untaggable_models
end
