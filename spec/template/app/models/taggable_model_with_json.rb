if using_postgresql? && postgresql_support_json?
  class TaggableModelWithJson < ActiveRecord::Base
    acts_as_taggable
    make_taggable :skills
  end
end
