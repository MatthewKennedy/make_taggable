class OtherCachedModel < ActiveRecord::Base
  make_taggable :languages, :statuses, :glasses
end
