class OtherTaggableModel < ActiveRecord::Base
  make_taggable :tags, :languages
  make_taggable :needs, :offerings
end
