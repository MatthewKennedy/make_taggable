# This migration comes from make_taggable_engine (originally 3)
class AddIndexToTags < ActiveRecord::Migration[6.0]
  def change
    add_index MakeTaggable.tags_table, :name, unique: true
  end
end

